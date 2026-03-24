defmodule CQRS.Enrichments.Events.ProviderEnrichmentCompleted do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :phone, String.t(), enforce: true
    field :provider_type, String.t(), enforce: true
    # "success" | "error"
    field :status, String.t(), enforce: true
    field :enrichment_data, map()
    field :error_data, map()
    field :quality_metadata, map(), default: %{}
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer(), default: 1
  end
end
