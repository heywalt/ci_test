defmodule CQRS.Enrichments.EnrichmentAggregate do
  @moduledoc false

  use TypedStruct

  require Logger

  alias __MODULE__, as: Enrichment
  alias CQRS.Enrichments.Commands, as: Cmd
  alias CQRS.Enrichments.Events
  alias Repo.Types.TenDigitPhone

  defmodule Lifespan do
    @moduledoc false

    @behaviour Commanded.Aggregates.AggregateLifespan

    alias CQRS.Enrichments.Events

    # Timeout constants
    @provider_timeout :timer.minutes(10)
    @post_composition_timeout :timer.minutes(6)
    @final_timeout :timer.minutes(4)

    # ========== Commands ==========
    @impl true
    def after_command(_cmd), do: @provider_timeout

    # ========== Events - New Composable Flow ==========
    @impl true
    def after_event(%Events.EnrichmentRequested{}), do: @provider_timeout
    def after_event(%Events.ProviderEnrichmentRequested{}), do: @provider_timeout
    def after_event(%Events.ProviderEnrichmentCompleted{status: "success"}), do: @provider_timeout
    def after_event(%Events.ProviderEnrichmentCompleted{status: "error"}), do: @provider_timeout
    def after_event(%Events.EnrichmentCompositionRequested{}), do: @provider_timeout
    def after_event(%Events.EnrichmentComposed{}), do: @post_composition_timeout

    # ========== Events - Legacy Flow ==========
    def after_event(%Events.EnrichedWithEndato{}), do: @provider_timeout
    def after_event(%Events.EnrichedWithFaraday{}), do: @provider_timeout
    def after_event(%Events.EnrichedWithTrestle{}), do: @provider_timeout
    def after_event(%Events.EndatoEnrichmentRequested{}), do: @provider_timeout
    def after_event(%Events.FaradayEnrichmentRequested{}), do: @provider_timeout
    def after_event(%Events.Jittered{}), do: @final_timeout

    # ========== Events - Catch-all ==========
    def after_event(_event), do: @provider_timeout

    # ========== Errors - Critical/Unrecoverable ==========
    @impl true
    def after_error({:error, :invalid_enrichment_id}), do: {:stop, :invalid_enrichment_id}
    def after_error({:error, :enrichment_not_found}), do: {:stop, :enrichment_not_found}

    # ========== Errors - Provider-related (recoverable) ==========
    def after_error({:error, :provider_timeout}), do: @provider_timeout
    def after_error({:error, :provider_error}), do: @provider_timeout

    # ========== Errors - Exceptions ==========
    def after_error(error) when is_exception(error), do: {:stop, error}

    # ========== Errors - Default ==========
    def after_error(_error), do: @provider_timeout
  end

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t()
    field :addresses, {:array, :map}, default: []
    field :emails, {:array, :string}, default: []
    field :first_name, :string
    field :last_name, :string
    field :phone, TenDigitPhone.t()
    field :ptt, integer, default: 0
    field :timestamp, NaiveDateTime.t()
    field :last_provider_requested, String.t()
    field :last_provider_succeeded, String.t()
    field :last_provider_failed, String.t()
    field :provider_request_timestamp, NaiveDateTime.t()
    field :provider_success_timestamp, NaiveDateTime.t()
    field :provider_failure_timestamp, NaiveDateTime.t()
    field :last_composition_timestamp, NaiveDateTime.t()
    field :alternate_names, {:array, :string}, default: []
  end

  def execute(_state, %Cmd.RequestEnrichment{} = cmd) do
    %Events.EnrichmentRequested{
      id: cmd.id,
      email: cmd.email,
      first_name: cmd.first_name,
      last_name: cmd.last_name,
      phone: cmd.phone,
      user_id: cmd.user_id,
      timestamp: cmd.timestamp
    }
  end

  def execute(_state, %Cmd.EnrichWithEndato{} = cmd) do
    cmd
    |> Map.from_struct()
    |> then(&struct(Events.EnrichedWithEndato, &1))
  end

  def execute(_state, %Cmd.EnrichWithFaraday{} = cmd) do
    cmd
    |> Map.from_struct()
    |> then(&struct(Events.EnrichedWithFaraday, &1))
  end

  def execute(_state, %Cmd.EnrichWithTrestle{} = cmd) do
    %Events.EnrichedWithTrestle{
      id: cmd.id,
      addresses: cmd.addresses,
      age_range: cmd.age_range,
      emails: cmd.emails,
      first_name: cmd.first_name,
      last_name: cmd.last_name,
      phone: cmd.phone,
      timestamp: cmd.timestamp,
      version: 1
    }
  end

  def execute(%{ptt: 0}, %Cmd.Jitter{}), do: :ok

  def execute(state, %Cmd.Jitter{} = evt) do
    %Events.Jittered{id: evt.id, score: jittered_ptt(state.ptt), timestamp: evt.timestamp}
  end

  def execute(_state, %Cmd.RequestProviderEnrichment{} = cmd) do
    %Events.ProviderEnrichmentRequested{
      id: cmd.id,
      provider_type: cmd.provider_type,
      contact_data: cmd.contact_data,
      provider_config: cmd.provider_config,
      timestamp: cmd.timestamp
    }
  end

  def execute(state, %Cmd.CompleteProviderEnrichment{} = cmd) do
    # Fall back to phone from enrichment_data if state.phone is nil
    phone = state.phone || (cmd.enrichment_data && cmd.enrichment_data[:phone])

    %Events.ProviderEnrichmentCompleted{
      id: cmd.id,
      phone: phone,
      provider_type: cmd.provider_type,
      status: cmd.status,
      enrichment_data: cmd.enrichment_data,
      error_data: cmd.error_data,
      quality_metadata: cmd.quality_metadata,
      timestamp: cmd.timestamp
    }
  end

  def execute(_state, %Cmd.RequestEnrichmentComposition{} = cmd) do
    %Events.EnrichmentCompositionRequested{
      id: cmd.id,
      provider_data: cmd.provider_data,
      composition_rules: cmd.composition_rules,
      timestamp: cmd.timestamp
    }
  end

  def execute(state, %Cmd.CompleteEnrichmentComposition{} = cmd) do
    %Events.EnrichmentComposed{
      id: cmd.id,
      composed_data: cmd.composed_data,
      data_sources: cmd.data_sources,
      provider_scores: cmd.provider_scores,
      phone: cmd.composed_data[:phone] || state.phone,
      timestamp: cmd.timestamp,
      alternate_names: state.alternate_names
    }
  end

  def execute(_state, %Cmd.Reset{} = cmd) do
    %Events.EnrichmentReset{
      id: cmd.id,
      timestamp: cmd.timestamp
    }
  end

  def apply(state, %Events.EnrichmentRequested{} = evt) do
    %Enrichment{
      state
      | id: evt.id,
        first_name: state.first_name || evt.first_name,
        last_name: state.last_name || evt.last_name,
        phone: evt.phone,
        timestamp: evt.timestamp
    }
  end

  def apply(state, %Events.EnrichedWithEndato{}), do: state

  def apply(state, %Events.EndatoEnrichmentRequested{} = evt) do
    %Enrichment{
      state
      | id: evt.id,
        phone: evt.phone,
        first_name: evt.first_name,
        last_name: evt.last_name,
        emails: if(evt.email, do: [evt.email], else: []),
        timestamp: evt.timestamp
    }
  end

  def apply(state, %Events.FaradayEnrichmentRequested{}), do: state
  def apply(state, %Events.EnrichedWithFaraday{} = evt), do: %Enrichment{state | ptt: ptt(evt)}

  def apply(state, %Events.EnrichedWithTrestle{} = evt) do
    %Enrichment{
      state
      | id: evt.id,
        addresses: evt.addresses,
        emails: evt.emails,
        first_name: evt.first_name,
        last_name: evt.last_name
    }
  end

  def apply(state, %Events.Jittered{}), do: state

  def apply(state, %Events.ProviderEnrichmentRequested{} = evt) do
    %Enrichment{
      state
      | id: evt.id,
        timestamp: evt.timestamp,
        last_provider_requested: evt.provider_type,
        provider_request_timestamp: evt.timestamp
    }
  end

  def apply(state, %Events.ProviderEnrichmentCompleted{status: "success"} = evt) do
    # Extract alternate_names from Trestle enrichment data
    alternate_names =
      if evt.provider_type == "trestle" && is_map(evt.enrichment_data) do
        Map.get(evt.enrichment_data, :alternate_names, [])
      else
        state.alternate_names
      end

    %Enrichment{
      state
      | timestamp: evt.timestamp,
        last_provider_succeeded: evt.provider_type,
        provider_success_timestamp: evt.timestamp,
        alternate_names: alternate_names
    }
  end

  def apply(state, %Events.ProviderEnrichmentCompleted{status: "error"} = evt) do
    %Enrichment{
      state
      | timestamp: evt.timestamp,
        last_provider_failed: evt.provider_type,
        provider_failure_timestamp: evt.timestamp
    }
  end

  def apply(state, %Events.EnrichmentCompositionRequested{} = evt) do
    %Enrichment{
      state
      | timestamp: evt.timestamp
    }
  end

  def apply(state, %Events.EnrichmentComposed{} = evt) do
    ptt = Map.get(evt.composed_data, :ptt, state.ptt) || 0

    %Enrichment{
      state
      | timestamp: evt.timestamp,
        last_composition_timestamp: evt.timestamp,
        ptt: ptt
    }
  end

  def apply(_state, %Events.EnrichmentReset{} = evt) do
    %Enrichment{id: evt.id, timestamp: evt.timestamp}
  end

  defp jitter(value) do
    factor = 0.0005
    random = :rand.uniform(201) - 101
    jitter = Float.floor(random * factor, 4) + 1

    (value * jitter)
    |> trunc()
    |> min(98)
  end

  defp jittered_ptt(ptt) when is_float(ptt), do: jitter(ptt * 100)
  defp jittered_ptt(ptt) when is_integer(ptt), do: jitter(ptt)
  defp jittered_ptt(_else), do: 0

  defp ptt(%{propensity_to_transact: ptt}) when is_float(ptt), do: trunc(ptt * 100)
  defp ptt(%{propensity_to_transact: ptt}) when is_integer(ptt), do: ptt
  defp ptt(_event), do: 0
end
