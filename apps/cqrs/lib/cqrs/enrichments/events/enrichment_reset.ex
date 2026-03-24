defmodule CQRS.Enrichments.Events.EnrichmentReset do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
  end
end
