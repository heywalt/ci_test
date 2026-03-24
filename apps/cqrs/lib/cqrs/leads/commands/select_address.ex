defmodule CQRS.Leads.Commands.SelectAddress do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :street_1, String.t(), enforce: true
    field :street_2, String.t() | nil
    field :city, String.t(), enforce: true
    field :state, String.t(), enforce: true
    field :zip, String.t(), enforce: true
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{
        id: :binary_id,
        street_1: :string,
        street_2: :string,
        city: :string,
        state: :string,
        zip: :string
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :street_1, :city, :state, :zip])
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
