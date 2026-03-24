defmodule CQRS.Enrichments.Commands.CompleteProviderEnrichment do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :provider_type, String.t(), enforce: true
    # "success" | "error"
    field :status, String.t(), enforce: true
    field :enrichment_data, map()
    field :error_data, map()
    field :quality_metadata, map(), default: %{}
    field :timestamp, NaiveDateTime.t(), enforce: true
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
    alias CQRS.Enrichments.Validations

    def certify(cmd) do
      types = %{
        id: :binary_id,
        provider_type: :any,
        status: :any,
        enrichment_data: :map,
        error_data: :map,
        quality_metadata: :map,
        timestamp: :naive_datetime
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :provider_type, :status, :timestamp])
      |> Validations.validate_provider_type()
      |> Validations.validate_status()
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
