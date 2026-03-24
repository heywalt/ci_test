defmodule CQRS.Enrichments.Events.EnrichmentCompositionRequested do
  @moduledoc false

  use TypedStruct

  alias CQRS.Enrichments.Data.ProviderData

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :provider_data, [ProviderData.t()], enforce: true
    # Which rule set to apply
    field :composition_rules, atom(), default: :default
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer(), default: 1
  end

  @spec new(map) :: t
  def new(attrs) do
    {ts, attrs} =
      Map.pop_lazy(attrs, :timestamp, fn ->
        NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      end)

    struct!(__MODULE__, Map.put(attrs, :timestamp, ts))
  end
end
