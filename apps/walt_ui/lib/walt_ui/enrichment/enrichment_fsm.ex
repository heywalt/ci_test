defmodule WaltUi.Enrichment.EnrichmentFsm do
  @moduledoc false

  use GenStateMachine, callback_mode: [:state_functions, :state_enter]

  require Logger

  alias Ecto.Multi
  alias Repo.Types.TenDigitPhone
  alias WaltUi.Enrichment
  alias WaltUi.Projections.Contact, as: UserContact
  alias WaltUi.Providers.Endato
  alias WaltUi.Providers.Faraday
  alias WaltUi.UnifiedRecords.Contact, as: UnifiedContact

  @spec start_link(map) :: GenStateMachine.on_start()
  def start_link(data) do
    name = {:via, Registry, {Enrichment.EnrichmentRegistry, data.contact.id}}
    GenStateMachine.start_link(__MODULE__, data, name: name)
  end

  @spec child_spec(map) :: Supervisor.child_spec()
  def child_spec(data) do
    %{
      id: data.contact.id,
      start: {__MODULE__, :start_link, [data]},
      restart: :transient,
      type: :worker,
      shutdown: 5_000
    }
  end

  @impl true
  def init(%{contact: contact} = data) do
    Process.flag(:trap_exit, true)

    case contact do
      %UserContact{} ->
        Logger.metadata(contact_id: data.contact.id, module: __MODULE__)

      %UnifiedContact{} ->
        Logger.metadata(unified_contact_id: data.contact.id, module: __MODULE__)
    end

    {:ok, :new, data, [{:next_event, :internal, :triage}]}
  end

  def new(:enter, _prev_state, _data) do
    Logger.metadata(state: :new)
    :keep_state_and_data
  end

  def new(:internal, :triage, %{contact: %UserContact{}} = data) do
    case Repo.reload(data.contact) do
      nil ->
        Logger.info("User contact deleted before enrichment started")
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}

      %{first_name: name} when name in ["", nil] ->
        Logger.info("Skipping legacy enrichment - insufficient contact data")
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}

      %{last_name: name} when name in ["", nil] ->
        Logger.info("Skipping legacy enrichment - insufficient contact data")
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}

      %{} ->
        Logger.info("Skipping legacy enrichment - use new composable flow")
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}
    end
  end

  def new(:internal, :triage, %{contact: %UnifiedContact{}} = data) do
    case Repo.re_preload(data.contact, [:endato, :faraday]) do
      nil ->
        Logger.info("Unified contact deleted before enrichment started")
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}

      %{endato: %{first_name: fname, last_name: lname}} = _contact
      when fname not in ["", nil] and lname not in ["", nil] ->
        Logger.info("Skipping legacy enrichment update - use new composable flow")
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}

      %{endato: %{phone: phone}} = _contact when is_binary(phone) ->
        Logger.info("Skipping legacy enrichment update - use new composable flow")
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}

      _else ->
        Logger.info("Cannot update unified contact enrichment", reason: :invalid_data)
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}
    end
  end

  def endato(:enter, _prev_state, _data) do
    Logger.metadata(state: :endato)
    :keep_state_and_data
  end

  def endato(:internal, :fetch, data) do
    case fetch_endato(data) do
      {:ok, %{"person" => _} = body} ->
        Logger.info("Found candidate identity enrichment")

        {:next_state, :faraday, Map.put(data, :endato_resp, normalize_endato_resp(body)),
         [{:next_event, :internal, :fetch}]}

      {:ok, _no_match} ->
        Logger.info("Falling back to Endato caller ID")
        {:keep_state_and_data, [{:next_event, :internal, :caller_id}]}

      {:error, error} ->
        Logger.warning("Failed to fetch Endato contact data", details: inspect(error))
        {:keep_state_and_data, [{:next_event, :internal, :caller_id}]}
    end
  end

  def endato(:internal, :caller_id, data) do
    caller_id_fn = Keyword.get(data.opts, :caller_id_fn, &Enrichment.Endato.search_by_phone/1)
    {:ok, phone} = normalize_phone(data.contact)

    case caller_id_fn.(phone) do
      {:ok, %{"person" => _} = body} ->
        Logger.info("Found candidate identity enrichment")

        {:next_state, :faraday, Map.put(data, :endato_resp, normalize_endato_resp(body)),
         [{:next_event, :internal, :fetch}]}

      {:ok, _no_match} ->
        Logger.info("No Endato caller ID data found")
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}

      {:error, error} ->
        Logger.warning("Failed to get Endato caller ID data", details: inspect(error))
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}
    end
  end

  def faraday(:enter, _prev_state, _data) do
    Logger.metadata(state: :faraday)
    :keep_state_and_data
  end

  def faraday(:internal, :fetch, data) do
    faraday_fetch_fn = Keyword.get(data.opts, :faraday_fetch_fn, &faraday_by_identity_sets/2)

    with {:ok, phone} <- TenDigitPhone.cast(data.contact.phone),
         {:ok, http} <- faraday_fetch_fn.(phone, data.endato_resp),
         :ok <- confirm(http, data.endato_resp) do
      {:next_state, :record, Map.put(data, :faraday_http, http),
       [{:next_event, :internal, :create_or_update}]}
    else
      {:error, :age, message} ->
        Logger.info("Identity NOT confirmed", reason: :mismatch, details: message)
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}

      error ->
        Logger.warning("Error requesting Faraday data", details: inspect(error))
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}
    end
  end

  def record(:enter, _prev_state, _data) do
    Logger.metadata(state: :enter)
    :keep_state_and_data
  end

  # data.contact is a user contact, so we're creating a new unified contact
  def record(:internal, :create_or_update, %{contact: %UserContact{}} = data) do
    Multi.new()
    |> Multi.insert(:unified_contact, fn _ ->
      UnifiedContact.changeset(%{phone: data.contact.phone})
    end)
    |> Multi.insert(:endato, fn %{unified_contact: uni} ->
      data
      |> endato_attrs()
      |> Map.merge(%{phone: uni.phone, unified_contact_id: uni.id})
      |> Endato.changeset()
    end)
    |> Multi.insert(:faraday, fn %{unified_contact: uni} ->
      Faraday.http_changeset(%Faraday{}, data.faraday_http, %{unified_contact_id: uni.id})
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _result} ->
        {:next_state, :report, data, [{:next_event, :internal, :enriched}]}

      error ->
        Logger.warning("Error recording enrichment data", details: inspect(error))
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}
    end
  end

  # data.contact is a unified contact, so we're updating an existing unified contact
  def record(:internal, :create_or_update, %{contact: %UnifiedContact{}} = data) do
    Multi.new()
    |> Multi.update(:endato, fn _ ->
      Endato.changeset(data.contact.endato, endato_attrs(data))
    end)
    |> Multi.insert_or_update(:faraday, fn _ ->
      Faraday.http_changeset(data.contact.faraday || %Faraday{}, data.faraday_http, %{
        unified_contact_id: data.contact.id
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, multi} ->
        data.contact
        |> Repo.preload(:contacts)
        |> Map.get(:contacts, [])
        |> Enum.each(&sync_user_contact(&1, multi))

        {:next_state, :report, data, [{:next_event, :internal, :enriched}]}

      error ->
        Logger.warning("Error recording enrichment data", details: inspect(error))
        {:next_state, :report, data, [{:next_event, :internal, :unenriched}]}
    end
  end

  def report(:enter, _prev_state, _data) do
    Logger.metadata(state: :report)
    :keep_state_and_data
  end

  def report(:internal, :enriched, data) do
    if pid = Map.get(data, :report_to) do
      Logger.info("Reporting enrichment success")
      GenStateMachine.cast(pid, :enriched)
    end

    case data.contact do
      %UserContact{} -> {:stop, :normal, data}
      %UnifiedContact{} -> {:next_state, :cleanup, data, [{:next_event, :internal, :jitter}]}
    end
  end

  def report(:internal, :unenriched, data) do
    if pid = Map.get(data, :report_to) do
      Logger.info("Reporting enrichment failure")
      GenStateMachine.cast(pid, :unenriched)
    end

    {:stop, :normal, data}
  end

  def cleanup(:enter, _prev_state, _data) do
    Logger.metadata(state: :cleanup)
    :keep_state_and_data
  end

  def cleanup(:internal, :jitter, data) do
    with %{jitter: jitter} when not is_nil(jitter) <-
           Repo.re_preload(data.contact, :jitter),
         {:ok, _} <- Repo.delete(jitter) do
      Logger.info("Deleted outdated jitter record")
    else
      %{jitter: nil} -> Logger.info("No jitter record to delete")
      error -> Logger.warning("Error deleting jitter record", details: inspect(error))
    end

    {:stop, :normal, data}
  end

  defp confirm(%{"match_type" => match_type} = http, endato) when not is_nil(match_type) do
    confirm_age(http, endato)
  end

  defp confirm(_http, _endato) do
    {:error, :match_type, "No match type"}
  end

  defp confirm_age(%{"fdy_attribute_fig_age" => nil}, _endato), do: :ok
  defp confirm_age(_http, %{age: nil}), do: :ok

  defp confirm_age(http, endato) do
    faraday_age = Map.get(http, "fdy_attribute_fig_age", 0)

    if abs(faraday_age - endato.age) <= 5 do
      :ok
    else
      {:error, :age, "Age #{faraday_age} not within +/- 5 years of #{endato.age}"}
    end
  end

  defp endato_addresses(%{"person" => %{"address" => addr}}) do
    addr
    |> normalize_endato_address()
    |> List.wrap()
  end

  defp endato_addresses(%{"person" => %{"addresses" => addrs}}) do
    Enum.map(addrs, &normalize_endato_address/1)
  end

  defp endato_addresses(_http_body), do: []

  defp endato_attrs(data) do
    Map.merge(data.endato_resp, %{
      city: get_in(data.faraday_http, ["identity_set", "city"]),
      state: get_in(data.faraday_http, ["identity_set", "state"]),
      street_1: get_in(data.faraday_http, ["identity_set", "house_number_and_street"]),
      zip: get_in(data.faraday_http, ["identity_set", "postcode"])
    })
  end

  defp endato_email(%{"person" => %{"email" => email}}), do: email
  defp endato_email(%{"person" => %{"emails" => emails}}), do: List.first(emails)["email"]
  defp endato_email(_http_body), do: nil

  defp faraday_by_identity_sets(phone_number, endato) do
    endato.addresses
    |> Enum.map(fn addr ->
      %{
        city: addr.city,
        email: endato.email,
        house_number_and_street: String.trim("#{addr.street_1} #{addr.street_2}"),
        person_first_name: endato.first_name,
        person_last_name: endato.last_name,
        phone: phone_number,
        postcode: addr.zip,
        state: addr.state
      }
    end)
    |> Enrichment.Faraday.fetch_by_identity_sets()
  end

  defp fetch_endato(%{contact: %UserContact{}} = data) do
    fetch_fn = Keyword.get(data.opts, :endato_fetch_fn, &Enrichment.Endato.fetch_contact/1)
    fetch_fn.(data.contact)
  end

  defp fetch_endato(%{contact: %UnifiedContact{}} = data) do
    fetch_fn = Keyword.get(data.opts, :endato_fetch_fn, &Enrichment.Endato.fetch_contact/1)
    fetch_fn.(data.contact.endato)
  end

  defp get_user_contact_ptt(%{propensity_to_transact: ptt}) when is_float(ptt) do
    trunc(ptt * 100)
  end

  defp get_user_contact_ptt(_faraday), do: 0

  defp normalize_endato_address(addr) do
    %{
      city: addr["city"],
      state: addr["state"],
      street_1: addr["street"],
      street_2: addr["unit"],
      zip: addr["zip"]
    }
  end

  defp normalize_endato_resp(http_body) do
    %{
      addresses: endato_addresses(http_body),
      age: http_body |> get_in(["person", "age"]) |> to_int(),
      email: endato_email(http_body),
      first_name: get_in(http_body, ["person", "name", "firstName"]),
      last_name: get_in(http_body, ["person", "name", "lastName"])
    }
  end

  defp normalize_phone(%UserContact{} = contact) do
    TenDigitPhone.cast(contact.phone)
  end

  defp normalize_phone(%UnifiedContact{} = contact) do
    TenDigitPhone.cast(contact.endato.phone)
  end

  defp get_enrichment_type(nil), do: nil
  defp get_enrichment_type("address_full_name"), do: :best
  defp get_enrichment_type(_else), do: :lesser

  defp sync_user_contact(contact, attrs) do
    enrichment_type = get_enrichment_type(attrs.faraday)

    WaltUi.Contacts.update_contact(contact, %{
      city: attrs.endato.city,
      email: contact.email || attrs.endato.email,
      enrichment_type: enrichment_type,
      ptt: get_user_contact_ptt(attrs.faraday),
      state: attrs.endato.state,
      street_1: attrs.endato.street_1,
      street_2: attrs.endato.street_2,
      zip: attrs.endato.zip
    })
  end

  defp to_int(int) when is_integer(int), do: int

  defp to_int(str) when is_binary(str) do
    String.to_integer(str)
  rescue
    _ -> nil
  end

  defp to_int(_other), do: nil
end
