defmodule WaltUi.ProcessManagers.ContactEnrichmentManager do
  @moduledoc false

  use Commanded.ProcessManagers.ProcessManager,
    application: CQRS,
    start_from: :current,
    name: __MODULE__,
    event_timeout: :timer.seconds(10)

  use TypedStruct

  import Ecto.Query

  require Logger

  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Enrichments.Events.Jittered
  alias CQRS.Leads.Commands.JitterPtt
  alias CQRS.Leads.Commands.Unify
  alias CQRS.Leads.Commands.Update
  alias WaltUi.Enrichment.UnificationJob

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t()
  end

  @impl true
  def interested?(%{id: nil} = event) do
    Logger.error("ContactEnrichmentManager: Event without ID",
      module: __MODULE__,
      details: inspect(event)
    )

    false
  end

  def interested?(%EnrichmentComposed{id: id}), do: {:start, id}
  def interested?(%Jittered{id: id}), do: {:start, id}
  def interested?(_event), do: false

  @impl true
  def handle(_state, %EnrichmentComposed{} = event) do
    # Skip if phone is nil
    if event.phone do
      event.id
      |> eventable_contacts_query(event.phone)
      |> Repo.all()
      |> Enum.flat_map(&process_contact(&1, event))
    else
      []
    end
  end

  def handle(_state, %Jittered{} = event) do
    event.id
    |> enriched_contacts_query()
    |> Repo.all()
    |> Enum.map(fn contact ->
      %JitterPtt{
        id: contact.id,
        score: event.score,
        timestamp: event.timestamp
      }
    end)
  end

  @impl true
  def apply(state, event), do: %{state | id: event.id}

  @impl true
  def after_command(_state, %JitterPtt{}, _ctx), do: :stop
  def after_command(_state, %Unify{}, _ctx), do: :stop
  def after_command(_state, %Update{}, _ctx), do: :stop

  @impl true
  def error(error, event, ctx) do
    Logger.error("ContactEnrichmentManager: Error dispatching command",
      details: inspect(ctx.last_event),
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  defp enriched_contacts_query(enrichment_id) do
    from(con in WaltUi.Projections.Contact, where: con.enrichment_id == ^enrichment_id)
  end

  defp eventable_contacts_query(enrichment_id, phone) do
    from(con in enriched_contacts_query(enrichment_id),
      or_where: is_nil(con.enrichment_id) and con.standard_phone == ^phone
    )
  end

  defp process_contact(%{enrichment_id: enrichment_id} = contact, event)
       when not is_nil(enrichment_id) do
    Logger.info("Contact unification decision",
      event_id: event.id,
      contact_id: contact.id,
      action: "update",
      reason: "already_enriched",
      module: __MODULE__
    )

    [build_update_command(contact, event)]
  end

  defp process_contact(contact, event) do
    first_name = CQRS.Utils.get(event.composed_data, :first_name)
    last_name = CQRS.Utils.get(event.composed_data, :last_name)

    cond do
      !has_names_to_match?(first_name, last_name) ->
        []

      jaro_match?(contact, first_name, last_name, event) ->
        [build_unify_command(contact, event)]

      true ->
        insert_unification_job(contact, event)
        []
    end
  end

  defp has_names_to_match?(first_name, last_name) do
    first_name != nil && last_name != nil
  end

  defp jaro_match?(contact, first_name, last_name, event) do
    # Try primary names first
    primary_score = calculate_jaro_distance(contact, first_name, last_name)

    if primary_score > 0.70 do
      Logger.info("Name matching executed",
        contact_id: contact.id,
        event_id: event.id,
        jaro_distance: primary_score,
        match_type: "primary_names",
        gpt_fallback_used: false,
        match_result: true,
        module: __MODULE__
      )

      true
    else
      # Try with alternate names
      try_alternate_names_jaro_match(contact, first_name, last_name, event, contact.id)
    end
  end

  defp insert_unification_job(contact, event) do
    enrichment_data = build_enrichment_data(event)
    enrichment_type = determine_enrichment_type(event)
    alternate_names = CQRS.Utils.get(event, :alternate_names, [])

    job_args = %{
      contact_id: contact.id,
      contact_first_name: contact.first_name,
      contact_last_name: contact.last_name,
      enrichment_id: event.id,
      enrichment_first_name: CQRS.Utils.get(event.composed_data, :first_name),
      enrichment_last_name: CQRS.Utils.get(event.composed_data, :last_name),
      enrichment_alternate_names: alternate_names,
      enrichment_data: enrichment_data,
      enrichment_type: enrichment_type,
      user_id: contact.user_id
    }

    case UnificationJob.new(job_args) |> Oban.insert() do
      {:ok, job} ->
        Logger.info("UnificationJob enqueued",
          contact_id: contact.id,
          event_id: event.id,
          job_id: job.id,
          module: __MODULE__
        )

      {:error, reason} ->
        Logger.error("Failed to enqueue UnificationJob",
          contact_id: contact.id,
          event_id: event.id,
          error: inspect(reason),
          module: __MODULE__
        )
    end
  end

  defp build_enrichment_data(event) do
    composed_data = event.composed_data

    %{}
    |> maybe_put(:ptt, CQRS.Utils.get(composed_data, :ptt))
    |> maybe_put(:city, CQRS.Utils.get(composed_data, :city))
    |> maybe_put(:state, CQRS.Utils.get(composed_data, :state))
    |> maybe_put(:street_1, CQRS.Utils.get(composed_data, :street_1))
    |> maybe_put(:street_2, CQRS.Utils.get(composed_data, :street_2))
    |> maybe_put(:zip, CQRS.Utils.get(composed_data, :zip))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp determine_enrichment_type(event) do
    min_score = min_provider_score(event.provider_scores)
    if min_score >= 90, do: "best", else: "lesser"
  end

  defp try_alternate_names_jaro_match(
         contact,
         enrichment_first,
         enrichment_last,
         event,
         contact_id
       ) do
    case CQRS.Utils.get(event, :alternate_names, []) do
      [] ->
        Logger.info("Name matching executed",
          contact_id: contact_id,
          event_id: event.id,
          jaro_distance: 0,
          match_type: "alternate_names",
          gpt_fallback_used: false,
          match_result: false,
          module: __MODULE__
        )

        false

      alternate_names ->
        best_score =
          calculate_best_alternate_jaro_score(
            contact,
            enrichment_first,
            enrichment_last,
            alternate_names
          )

        result = best_score > 0.70

        Logger.info("Name matching executed",
          contact_id: contact_id,
          event_id: event.id,
          jaro_distance: best_score,
          match_type: "alternate_names",
          gpt_fallback_used: false,
          match_result: result,
          module: __MODULE__
        )

        result
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

  defp calculate_jaro_distance(contact, first_name, last_name) do
    fname = contact.first_name |> to_string() |> String.jaro_distance(to_string(first_name))
    lname = contact.last_name |> to_string() |> String.jaro_distance(to_string(last_name))
    min(fname, lname)
  end

  defp timestamp do
    NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
  end

  defp build_unify_command(contact, event) do
    Logger.info("Contact unification decision",
      event_id: event.id,
      contact_id: contact.id,
      action: "unify",
      reason: "jaro_match",
      module: __MODULE__
    )

    event
    |> to_attrs()
    |> Map.merge(%{id: contact.id, enrichment_id: event.id})
    |> then(&struct(Unify, &1))
  end

  defp build_update_command(contact, event) do
    %Update{
      id: contact.id,
      attrs: to_attrs(event),
      timestamp: timestamp(),
      user_id: contact.user_id
    }
  end

  defp min_provider_score(provider_scores) when is_map(provider_scores) do
    case Map.values(provider_scores) do
      [] -> 0
      scores -> Enum.min(scores)
    end
  end

  defp to_attrs(event) do
    composed_data = event.composed_data

    %{
      city: CQRS.Utils.get(composed_data, :city),
      email: CQRS.Utils.get(composed_data, :email),
      enrichment_type: enrichment_type_from_scores(event.provider_scores),
      ptt: CQRS.Utils.get(composed_data, :ptt, 0),
      state: CQRS.Utils.get(composed_data, :state),
      street_1: CQRS.Utils.get(composed_data, :street_1),
      street_2: CQRS.Utils.get(composed_data, :street_2),
      zip: CQRS.Utils.get(composed_data, :zip)
    }
  end

  defp enrichment_type_from_scores(provider_scores) do
    min_score = min_provider_score(provider_scores)

    max_score =
      case Map.values(provider_scores) do
        [] -> 0
        scores -> Enum.max(scores)
      end

    cond do
      min_score >= 85 -> :best
      max_score >= 20 -> :lesser
      true -> nil
    end
  end
end
