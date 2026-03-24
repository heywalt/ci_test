defmodule WaltUi.ProcessManagers.UnificationManager do
  @moduledoc false

  use Commanded.ProcessManagers.ProcessManager,
    application: CQRS,
    name: __MODULE__,
    start_from: :current

  use TypedStruct

  require Logger

  import Ecto.Query

  alias CQRS.Enrichments.Commands.RequestEnrichment
  alias CQRS.Leads.Commands.Unify
  alias CQRS.Leads.Events.LeadCreated
  alias Repo.Types.TenDigitPhone
  alias WaltUi.Enrichment.UnificationJob
  alias WaltUi.Projections.Faraday
  alias WaltUi.Projections.Trestle

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t()
  end

  @impl true
  def interested?(%LeadCreated{id: id}), do: {:start, id}
  def interested?(_event), do: false

  @impl true
  def handle(_state, %LeadCreated{} = event) do
    with {:ok, phone} <- TenDigitPhone.cast(event.phone),
         :ok <- validate_name(event.first_name),
         {:ok, enrichment_data} <- find_available_enrichment_data(phone) do
      case names_match?(event, enrichment_data) do
        :match ->
          build_unify_command(event, enrichment_data)

        :no_trestle ->
          # Can't do name matching without Trestle, request enrichment
          RequestEnrichment.new(%{
            email: event.email,
            first_name: event.first_name,
            last_name: event.last_name,
            phone: phone,
            user_id: event.user_id
          })

        :jaro_failed ->
          # Have Trestle data but Jaro matching failed, schedule OpenAI job
          insert_unification_job(event, enrichment_data)
          []
      end
    else
      {:error, :not_found, phone} ->
        RequestEnrichment.new(%{
          email: event.email,
          first_name: event.first_name,
          last_name: event.last_name,
          phone: phone,
          user_id: event.user_id
        })

      _else ->
        []
    end
  end

  @impl true
  def apply(state, event), do: %{state | id: event.id}

  @impl true
  def after_command(_state, %Unify{}), do: :stop
  def after_command(_state, %RequestEnrichment{}), do: :stop

  @impl true
  def error(error, event, _ctx) do
    Logger.error("Error in process manager",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  defp enrichment_type(%{match_type: nil}), do: nil
  defp enrichment_type(%{match_type: "address_full_name"}), do: :best
  defp enrichment_type(_else), do: :lesser

  defp find_available_enrichment_data(phone) do
    enrichment_id = UUID.uuid5(:oid, phone)

    data =
      Repo.one(
        from t in Trestle,
          left_join: f in Faraday,
          on: t.id == f.id,
          where: t.id == ^enrichment_id,
          select: %{
            trestle: t,
            faraday: f,
            enrichment_id: t.id
          }
      )

    case data do
      nil -> {:error, :not_found, phone}
      %{trestle: nil, faraday: nil} -> {:error, :not_found, phone}
      map -> {:ok, map}
    end
  end

  defp jaro_match?(contact, first_name, last_name) do
    fname = contact.first_name |> to_string() |> String.jaro_distance(to_string(first_name))
    lname = contact.last_name |> to_string() |> String.jaro_distance(to_string(last_name))
    fname > 0.70 && lname > 0.70
  end

  defp jaro_match_with_alternates?(contact, enrichment_first, enrichment_last, alternate_names) do
    case alternate_names do
      names when is_list(names) and length(names) > 0 ->
        best_score =
          calculate_best_alternate_jaro_score(
            contact,
            enrichment_first,
            enrichment_last,
            alternate_names
          )

        best_score > 0.70

      _ ->
        false
    end
  end

  defp calculate_best_alternate_jaro_score(
         contact,
         _enrichment_first,
         _enrichment_last,
         alternate_names
       ) do
    contact_first = to_string(contact.first_name)
    contact_last = to_string(contact.last_name)

    # Try contact name against each alternate name
    alternate_names
    |> Enum.map(&parse_alternate_name/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn {alt_first, alt_last} ->
      fname_score = String.jaro_distance(contact_first, to_string(alt_first || ""))
      lname_score = String.jaro_distance(contact_last, to_string(alt_last || ""))
      min(fname_score, lname_score)
    end)
    |> Enum.max(fn -> 0 end)
  end

  defp parse_alternate_name(name) when is_binary(name) do
    case String.split(String.trim(name), " ", trim: true) do
      [] -> nil
      [single_name] -> {single_name, nil}
      [first | rest] -> {first, Enum.join(rest, " ")}
    end
  end

  defp parse_alternate_name(_), do: nil

  defp names_match?(event, enrichment_data) do
    case enrichment_data.trestle do
      nil ->
        # No Trestle data - can't do name matching, should request enrichment
        :no_trestle

      trestle_data ->
        first_name = trestle_data.first_name
        last_name = trestle_data.last_name
        alternate_names = trestle_data.alternate_names || []

        primary_match = jaro_match?(event, first_name, last_name)

        alternate_match =
          jaro_match_with_alternates?(event, first_name, last_name, alternate_names)

        if primary_match || alternate_match do
          :match
        else
          # Don't call OpenAI sync, let caller schedule job
          :jaro_failed
        end
    end
  end

  defp insert_unification_job(event, enrichment_data) do
    trestle = enrichment_data.trestle
    faraday = enrichment_data.faraday

    job_args = %{
      contact_id: event.id,
      contact_first_name: event.first_name,
      contact_last_name: event.last_name,
      enrichment_id: enrichment_data.enrichment_id,
      enrichment_first_name: trestle && trestle.first_name,
      enrichment_last_name: trestle && trestle.last_name,
      enrichment_alternate_names: (trestle && trestle.alternate_names) || [],
      enrichment_data: build_enrichment_data_for_job(trestle, faraday),
      enrichment_type: determine_enrichment_type_string(trestle, faraday),
      user_id: event.user_id
    }

    case UnificationJob.new(job_args) |> Oban.insert() do
      {:ok, job} ->
        Logger.info("UnificationJob enqueued",
          contact_id: event.id,
          event_id: enrichment_data.enrichment_id,
          job_id: job.id,
          module: __MODULE__
        )

      {:error, reason} ->
        Logger.error("Failed to enqueue UnificationJob",
          contact_id: event.id,
          event_id: enrichment_data.enrichment_id,
          error: inspect(reason),
          module: __MODULE__
        )
    end
  end

  defp build_enrichment_data_for_job(trestle, faraday) do
    # Extract address from Trestle's embedded addresses structure
    address_data =
      case trestle do
        %{addresses: [address | _]} -> address
        _ -> %{}
      end

    %{}
    |> maybe_put(:street_1, Map.get(address_data, :street_1))
    |> maybe_put(:street_2, Map.get(address_data, :street_2))
    |> maybe_put(:city, Map.get(address_data, :city))
    |> maybe_put(:state, Map.get(address_data, :state))
    |> maybe_put(:zip, Map.get(address_data, :zip))
    |> maybe_put(:ptt, get_ptt_score(faraday))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp determine_enrichment_type_string(trestle, faraday) do
    case determine_enrichment_type(trestle, faraday) do
      :best -> "best"
      :lesser -> "lesser"
      nil -> nil
    end
  end

  defp build_unify_command(event, enrichment_data) do
    trestle = enrichment_data.trestle
    faraday = enrichment_data.faraday

    address_data = select_address(faraday, trestle)

    %Unify{
      id: event.id,
      enrichment_id: enrichment_data.enrichment_id,
      enrichment_type: determine_enrichment_type(trestle, faraday),
      ptt: get_ptt_score(faraday),
      street_1: Map.get(address_data, :street_1),
      street_2: Map.get(address_data, :street_2),
      city: Map.get(address_data, :city),
      state: Map.get(address_data, :state),
      zip: Map.get(address_data, :zip)
    }
  end

  defp select_address(%{address: address} = faraday, _trestle) when is_binary(address) do
    %{
      street_1: faraday.address,
      street_2: nil,
      city: faraday.city,
      state: faraday.state,
      zip: faraday.postcode
    }
  end

  defp select_address(_faraday, trestle) do
    select_trestle_address(trestle)
  end

  defp select_trestle_address(%{addresses: addresses}) when is_list(addresses) do
    non_po_box = Enum.find(addresses, &(not po_box?(&1)))

    case non_po_box do
      nil -> List.first(addresses) || %{}
      address -> address
    end
  end

  defp select_trestle_address(_trestle), do: %{}

  defp po_box?(nil), do: false

  defp po_box?(%{street_1: street_1}) when is_binary(street_1) do
    street_1
    |> String.downcase()
    |> String.replace(".", "")
    |> String.starts_with?("po box")
  end

  defp po_box?(_address), do: false

  defp get_ptt_score(nil), do: 0
  defp get_ptt_score(faraday), do: ptt(faraday)

  defp determine_enrichment_type(trestle, faraday) do
    cond do
      faraday && enrichment_type(faraday) -> enrichment_type(faraday)
      # Have enrichment data but no quality score
      trestle -> :lesser
      true -> nil
    end
  end

  defp ptt(%{propensity_to_transact: ptt}) when is_float(ptt), do: trunc(ptt * 100)
  defp ptt(%{propensity_to_transact: ptt}) when is_integer(ptt), do: ptt
  defp ptt(_event), do: 0

  @familial_regex ~r/^wife$|^wifey$|^husband$|^hubby$|^babe$|^baby$|^love$|^mother$|^mom$|^ma$|^mama$|^mommy$|^father$|^dad$|^da$|^dada$|^daddy$|^sister$|^sis$|^brother$|^bro$|^aunt$|^auntie$|^uncle$|^unc$|^grandmother$|^grandma$|^gram$|^nana$|^mimi$|^grandfather$|^grandpa$|^gramps$|^papa$|^pop$|^cousin$|^cuz$|^niece$|^nephew$|^daughter$|^son$|^granddaughter$|^grandaughter$|^grandson$|^godmother$|^godfather$|^goddaughter$|^godson$|^papi$/i

  defp validate_name(name) do
    if name |> to_string() |> String.match?(@familial_regex) do
      :error
    else
      :ok
    end
  end
end
