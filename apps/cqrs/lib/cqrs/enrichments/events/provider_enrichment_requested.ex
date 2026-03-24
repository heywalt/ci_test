defmodule CQRS.Enrichments.Events.ProviderEnrichmentRequested do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :provider_type, String.t(), enforce: true
    field :contact_data, map(), enforce: true
    field :provider_config, map(), default: %{}
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer(), default: 1
  end
end
