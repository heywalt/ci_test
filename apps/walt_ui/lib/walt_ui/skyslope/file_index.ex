defmodule WaltUi.Skyslope.FileIndex do
  @moduledoc false

  use TypedStruct
  import Ecto.Changeset
  require Logger

  typedstruct do
    field :document_count, integer, default: 0
    field :envelope_count, integer, default: 0
    field :id, integer, enforce: true
    field :name, String.t(), enforce: true
    field :type, String.t(), enforce: true
  end

  @spec from_http(map) :: t | nil
  def from_http(map) do
    attrs = http_attrs(map)

    types = %{
      document_count: :integer,
      envelope_count: :integer,
      id: :integer,
      name: :string,
      type: :string
    }

    {struct(__MODULE__), types}
    |> cast(attrs, Map.keys(types))
    |> validate_required([:id, :name, :type])
    |> case do
      %{valid?: true} ->
        struct(__MODULE__, attrs)

      changeset ->
        Logger.warning("Skyslope files could not be parsed", reason: inspect(changeset.errors))
        nil
    end
  end

  defp http_attrs(map) do
    %{
      document_count: map["documentCount"],
      envelope_count: map["envelopeCount"],
      id: map["id"],
      name: map["name"],
      type: map["representationType"]
    }
  end
end
