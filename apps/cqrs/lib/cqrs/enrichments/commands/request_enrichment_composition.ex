defmodule CQRS.Enrichments.Commands.RequestEnrichmentComposition do
  @moduledoc false

  use TypedStruct

  alias CQRS.Enrichments.Data.ProviderData

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :provider_data, [ProviderData.t()], enforce: true
    field :composition_rules, atom(), enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer(), default: 1
  end

  @spec new(map) :: t
  def new(attrs) do
    {ts, attrs} =
      Map.pop_lazy(attrs, :timestamp, fn ->
        NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      end)

    # Convert provider_data maps to ProviderData structs
    attrs =
      case Map.get(attrs, :provider_data) do
        provider_data when is_list(provider_data) ->
          converted_provider_data =
            Enum.map(provider_data, fn
              %ProviderData{} = data -> data
              data when is_map(data) -> struct(ProviderData, data)
            end)

          Map.put(attrs, :provider_data, converted_provider_data)

        _ ->
          attrs
      end

    struct!(__MODULE__, Map.put(attrs, :timestamp, ts))
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{
        id: :binary_id,
        provider_data: {:array, :map},
        composition_rules: :any,
        timestamp: :naive_datetime,
        version: :integer
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :provider_data, :composition_rules, :timestamp])
      |> validate_inclusion(:composition_rules, [:default, :quality_based])
      |> validate_provider_data()
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end

    defp validate_provider_data(changeset) do
      provider_data = get_field(changeset, :provider_data)

      if provider_data == [] do
        add_error(changeset, :provider_data, "must have at least one provider result")
      else
        provider_data
        |> Enum.with_index()
        |> Enum.reduce(changeset, &validate_single_provider/2)
      end
    end

    defp validate_single_provider({data, index}, acc) do
      provider_struct =
        case data do
          %ProviderData{} = existing -> existing
          map when is_map(map) -> struct(ProviderData, map)
        end

      case ProviderData.validate(provider_struct) do
        :ok ->
          acc

        {:error, _errors} ->
          add_error(acc, :provider_data, "has invalid provider data at index #{index}")
      end
    end
  end
end
