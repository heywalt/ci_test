defmodule CQRS.Enrichments.Commands.CompleteEnrichmentComposition do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :composed_data, map(), enforce: true
    field :data_sources, map(), enforce: true
    field :provider_scores, map(), enforce: true
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

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{
        id: :binary_id,
        composed_data: :map,
        data_sources: :map,
        provider_scores: :map,
        timestamp: :naive_datetime,
        version: :integer
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :composed_data, :data_sources, :provider_scores, :timestamp])
      |> validate_data_structures()
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end

    defp validate_data_structures(changeset) do
      composed_data = get_field(changeset, :composed_data)
      data_sources = get_field(changeset, :data_sources)
      provider_scores = get_field(changeset, :provider_scores)

      changeset
      |> validate_map_structure(:composed_data, composed_data)
      |> validate_map_structure(:data_sources, data_sources)
      |> validate_map_structure(:provider_scores, provider_scores)
    end

    defp validate_map_structure(changeset, _field, value) when is_map(value), do: changeset

    defp validate_map_structure(changeset, field, _value) do
      add_error(changeset, field, "must be a map")
    end
  end
end
