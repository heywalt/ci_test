defmodule CQRS.Enrichments.Commands.RequestProviderEnrichment do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :provider_type, String.t(), enforce: true
    field :contact_data, map(), enforce: true
    field :provider_config, map(), default: %{}
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
        contact_data: :map,
        provider_config: :map,
        timestamp: :naive_datetime
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :provider_type, :contact_data, :timestamp])
      |> Validations.validate_provider_type()
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
