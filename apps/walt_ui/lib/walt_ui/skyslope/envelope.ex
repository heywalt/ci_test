defmodule WaltUi.Skyslope.Envelope do
  @moduledoc false

  use TypedStruct
  import Ecto.Changeset
  require Logger

  typedstruct do
    field :document_count, integer, default: 0
    field :file_id, integer, enforce: true
    field :id, String.t(), enforce: true
    field :name, String.t()
    field :signer_count, integer, default: 0
    field :status, String.t(), enforce: true
  end

  @spec from_http(map) :: {:ok, t} | {:error, term}
  def from_http(map) do
    attrs = http_attrs(map)

    types = %{
      document_count: :integer,
      file_id: :integer,
      id: :string,
      name: :string,
      signer_count: :integer,
      status: :string
    }

    {struct(__MODULE__), types}
    |> cast(attrs, Map.keys(types))
    |> validate_required([:file_id, :id, :status])
    |> case do
      %{valid?: true} ->
        struct(__MODULE__, attrs)

      changeset ->
        Logger.warning("Skyslope envelopes could not be parsed",
          reason: inspect(changeset.errors)
        )

        nil
    end
  end

  defp http_attrs(map) do
    %{
      document_count: length(map["documentIds"]),
      file_id: map["fileId"],
      id: map["id"],
      name: map["name"],
      signer_count: length(map["signers"]),
      status: map["status"]
    }
  end
end
