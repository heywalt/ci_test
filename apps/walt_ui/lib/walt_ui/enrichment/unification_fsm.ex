defmodule WaltUi.Enrichment.UnificationFsm do
  @moduledoc false

  use GenStateMachine, callback_mode: [:state_functions, :state_enter]

  require Logger

  alias Repo.Types.TenDigitPhone
  alias WaltUi.Contacts, as: UserContacts
  alias WaltUi.Enrichment
  alias WaltUi.Enrichment.OpenAi
  alias WaltUi.UnifiedRecords

  @typep user_contact_id :: Ecto.UUID.t()

  @await_timeout Application.compile_env(:walt_ui, [__MODULE__, :await_timeout], 2_000)

  @enrichment_timeout Application.compile_env(
                        :walt_ui,
                        [__MODULE__, :enrichment_timeout],
                        900_000
                      )

  @max_retries Application.compile_env(:walt_ui, [__MODULE__, :max_retries], 12)
  @retry_interval Application.compile_env(:walt_ui, [__MODULE__, :retry_interval_ms], 10_000)

  @spec start_link(user_contact_id, Keyword.t()) :: GenStateMachine.on_start()
  def start_link(user_contact_id, opts) do
    name = {:via, Registry, {Enrichment.UnificationRegistry, user_contact_id}}
    data = %{user_contact_id: user_contact_id, opts: opts}

    GenStateMachine.start_link(__MODULE__, data, name: name)
  end

  @spec child_spec({user_contact_id, Keyword.t()}) :: Supervisor.child_spec()
  def child_spec({user_contact_id, opts}) do
    %{
      id: user_contact_id,
      start: {__MODULE__, :start_link, [user_contact_id, opts]},
      restart: :transient,
      type: :worker,
      shutdown: 5_000
    }
  end

  @impl true
  def init(data) do
    Process.flag(:trap_exit, true)
    Logger.metadata(contact_id: data.user_contact_id, module: __MODULE__)

    {:ok, :new, data, [{:next_event, :internal, :await}]}
  end

  def new(:enter, _prev_state, _data) do
    Logger.metadata(state: :new)
    :keep_state_and_data
  end

  def new(_internal_or_timeout, :await, data) do
    case UserContacts.get_contact(data.user_contact_id) do
      nil ->
        Logger.debug("Awaiting user contact projection")
        {:keep_state_and_data, [{:state_timeout, @await_timeout, :await}]}

      user_contact ->
        {:keep_state, Map.put(data, :user_contact, user_contact),
         [{:next_event, :internal, :validate_phone}]}
    end
  end

  def new(:internal, :validate_phone, data) do
    case TenDigitPhone.cast(data.user_contact.phone) do
      {:ok, _phone} ->
        {:keep_state_and_data, [{:next_event, :internal, :validate_name}]}

      :error ->
        Logger.info("Unification stopped for invalid phone number",
          details: data.user_contact.phone
        )

        {:stop, :normal, data}
    end
  end

  def new(:internal, :validate_name, data) do
    if familial_name?(data.user_contact.first_name) do
      Logger.info("Unification stopped for familial name", details: data.user_contact.first_name)
      {:stop, :normal, data}
    else
      {:next_state, :matching, data, [{:next_event, :internal, :match}]}
    end
  end

  def matching(:enter, _prev_state, _data) do
    Logger.metadata(state: :matching)
    :keep_state_and_data
  end

  def matching(:internal, :match, data) do
    case UnifiedRecords.get_contacts_by(
           phone: data.user_contact.phone,
           preload: [:endato, :faraday]
         ) do
      [] ->
        Logger.info("Did not find unified contact match for contact")
        {:next_state, :no_candidate_match, data, [{:next_event, :internal, :enrich}]}

      [uni] ->
        Logger.info("Found unified contact match for contact", unified_contact_id: uni.id)

        {:next_state, :candidate_match, Map.put(data, :unified_contact, uni),
         [{:next_event, :internal, :link_with_jaro_distance}]}

      _multi ->
        Logger.error("Found multiple unified contacts matching phone number")
        {:stop, :normal, data}
    end
  end

  def no_candidate_match(:enter, _prev_state, _data) do
    Logger.metadata(state: :no_candidate_match)
    :keep_state_and_data
  end

  def no_candidate_match(:internal, :enrich, data) do
    enrichment_fn =
      Keyword.get(data.opts, :enrichment_fn, fn data ->
        data = %{contact: data.user_contact, report_to: self(), opts: data.opts}

        DynamicSupervisor.start_child(
          Enrichment.EnrichmentSupervisor,
          {Enrichment.EnrichmentFsm, data}
        )
      end)

    case enrichment_fn.(data) do
      {:ok, _pid} ->
        {:keep_state_and_data, [{:state_timeout, @enrichment_timeout, :waiting_for_enrichment}]}

      {:ok, _pid, _} ->
        {:keep_state_and_data, [{:state_timeout, @enrichment_timeout, :waiting_for_enrichment}]}

      {:error, {:already_stated, _pid}} ->
        {:keep_state_and_data, [{:state_timeout, @enrichment_timeout, :waiting_for_enrichment}]}

      error ->
        Logger.warning("Error starting enrichment process", details: inspect(error))
        {:stop, :normal, data}
    end
  end

  def no_candidate_match(:state_timeout, :waiting_for_enrichment, data) do
    Logger.warning("Timed out waiting for enrichment to report back")
    {:stop, :normal, data}
  end

  def no_candidate_match(:cast, :enriched, data) do
    Logger.info("Enrichment reported success")
    {:next_state, :matching, data, [{:next_event, :internal, :match}]}
  end

  def no_candidate_match(:cast, :unenriched, data) do
    Logger.info("Enrichment reported failure")
    {:stop, :normal, data}
  end

  def candidate_match(:enter, _prev_state, data) do
    Logger.metadata(state: :candidate_match, unified_contact_id: data.unified_contact.id)
    :keep_state_and_data
  end

  def candidate_match(:internal, :link_with_jaro_distance, data) do
    if jaro_distance_match?(data.user_contact, data.unified_contact.endato) do
      Logger.info("Unified contact via jaro distance")
      {:next_state, :matched, data, [{:next_event, :internal, :update_contact}]}
    else
      {:keep_state_and_data, [{:next_event, :internal, :link_with_endato}]}
    end
  end

  def candidate_match(:internal, :link_with_endato, data) do
    chat_gpt_fn = Keyword.get(data.opts, :chat_gpt_fn, &OpenAi.contact_matches_data/2)

    case chat_gpt_fn.(data.user_contact, data.unified_contact.endato) do
      {:ok, true} ->
        Logger.info("Unified contact via GPT")
        {:next_state, :matched, data, [{:next_event, :internal, :update_contact}]}

      {:ok, false} ->
        Logger.info("Failed to unify contact via GPT")
        {:stop, :normal, data}

      {:error, %{message: "OpenAI request timeout"}} ->
        attempt = Map.get(data, :gpt_attempt, 0) + 1

        Logger.info("Timed out asking GPT to unify contact. Retrying.",
          details: "Attempt #{attempt}"
        )

        {:keep_state_and_data, [{:state_timeout, @retry_interval, {:retry, attempt}}]}

      {:error, error} ->
        Logger.warning("Error unifying contact via GPT", reason: inspect(error))
        {:stop, :normal, data}
    end
  end

  def candidate_match(:state_timeout, {:retry, attempt}, data) do
    if attempt > @max_retries do
      Logger.warning("Max GPT attempts made")
      {:stop, :normal, data}
    else
      {:keep_state, Map.put(data, :gpt_attempt, attempt),
       [{:next_event, :internal, :link_with_endato}]}
    end
  end

  def matched(:enter, _prev_state, _data) do
    Logger.metadata(state: :matched)
    :keep_state_and_data
  end

  def matched(:internal, :update_contact, data) do
    with {:reload, user_contact} when not is_nil(user_contact) <-
           {:reload, Repo.reload(data.user_contact)},
         updates = get_contact_updates(user_contact, data.unified_contact),
         {:ok, user_contact} <- UserContacts.update_contact(user_contact, updates) do
      {:stop, :normal, %{data | user_contact: user_contact}}
    else
      {:reload, nil} ->
        Logger.warning("User contact deleted before unification complete")
        {:stop, :normal, data}

      error ->
        Logger.error("Failed to update user contact", reason: inspect(error))
        {:stop, :normal, data}
    end
  end

  @familial_regex ~r/^wife$|^wifey$|^husband$|^hubby$|^babe$|^baby$|^love$|^mother$|^mom$|^ma$|^mama$|^mommy$|^father$|^dad$|^da$|^dada$|^daddy$|^sister$|^sis$|^brother$|^bro$|^aunt$|^auntie$|^uncle$|^unc$|^grandmother$|^grandma$|^gram$|^nana$|^mimi$|^grandfather$|^grandpa$|^gramps$|^papa$|^pop$|^cousin$|^cuz$|^niece$|^nephew$|^daughter$|^son$|^granddaughter$|^grandaughter$|^grandson$|^godmother$|^godfather$|^goddaughter$|^godson$|^papi$/i

  defp familial_name?(name) do
    name
    |> to_string()
    |> String.match?(@familial_regex)
  end

  defp get_contact_email_update(%{email: nil}, endato), do: %{email: endato.email}
  defp get_contact_email_update(_contact, _endato), do: %{}

  defp get_contact_ptt_score(%{propensity_to_transact: ptt}) when is_float(ptt) do
    trunc(ptt * 100)
  end

  defp get_contact_ptt_score(_else), do: 0

  defp get_contact_updates(user_contact, unified_contact) do
    address_attrs = Map.take(unified_contact.endato, [:city, :state, :street_1, :street_2, :zip])
    email_attrs = get_contact_email_update(user_contact, unified_contact.endato)
    enrichment_type = get_enrichment_type(unified_contact.faraday)
    ptt_score = get_contact_ptt_score(unified_contact.faraday)

    %{enrichment_type: enrichment_type, ptt: ptt_score, unified_contact_id: unified_contact.id}
    |> Map.merge(address_attrs)
    |> Map.merge(email_attrs)
  end

  defp get_enrichment_type(nil), do: nil
  defp get_enrichment_type("address_full_name"), do: :best
  defp get_enrichment_type(_else), do: :lesser

  defp jaro_distance_match?(contact, provider) do
    jaro_first_name(contact, provider) > 0.70 && jaro_last_name(contact, provider) > 0.70
  end

  defp jaro_first_name(one, two) do
    one.first_name
    |> to_string()
    |> String.jaro_distance(to_string(two.first_name))
  end

  defp jaro_last_name(one, two) do
    one.last_name
    |> to_string()
    |> String.jaro_distance(to_string(two.last_name))
  end
end
