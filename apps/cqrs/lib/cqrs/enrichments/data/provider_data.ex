defmodule CQRS.Enrichments.Data.ProviderData do
  @moduledoc false

  use TypedStruct
  import Ecto.Changeset
  alias CQRS.Enrichments.Validations

  @derive Jason.Encoder
  typedstruct do
    field :provider_type, String.t(), enforce: true
    # "success" | "error"
    field :status, String.t(), enforce: true
    field :enrichment_data, map()
    field :error_data, map()
    field :quality_metadata, map(), default: %{}
    field :received_at, NaiveDateTime.t(), enforce: true
  end

  @spec validate(t()) :: :ok | {:error, keyword()}
  def validate(provider_data) do
    types = %{
      provider_type: :any,
      status: :any,
      enrichment_data: :map,
      error_data: :map,
      quality_metadata: :map,
      received_at: :naive_datetime
    }

    {struct(__MODULE__), types}
    |> cast(Map.from_struct(provider_data), Map.keys(types))
    |> validate_required([:provider_type, :status, :received_at])
    |> Validations.validate_provider_type()
    |> Validations.validate_status()
    |> validate_status_data_consistency()
    |> case do
      %{valid?: true} -> :ok
      changeset -> {:error, changeset.errors}
    end
  end

  defp validate_status_data_consistency(changeset) do
    status = get_field(changeset, :status)
    enrichment_data = get_field(changeset, :enrichment_data)
    error_data = get_field(changeset, :error_data)

    case status do
      "success" when is_nil(enrichment_data) ->
        add_error(changeset, :enrichment_data, "is required when status is success")

      "error" when is_nil(error_data) ->
        add_error(changeset, :error_data, "is required when status is error")

      _ ->
        changeset
    end
  end
end
