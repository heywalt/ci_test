defmodule CQRS.Enrichments.Events.EnrichmentComposed do
  @moduledoc false

  use TypedStruct

  alias Repo.Types.TenDigitPhone

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    # Final enriched contact data
    field :composed_data, map(), enforce: true
    # %{age: :faraday, income: :trestle, ...}
    field :data_sources, map(), enforce: true
    # %{faraday: 95, trestle: 89, endato: 78}
    field :provider_scores, map(), enforce: true
    # Phone number for contact matching
    field :phone, TenDigitPhone.t(), enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer(), default: 1
    # Alternate names from Trestle for name matching
    field :alternate_names, {:array, :string}, default: []
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
