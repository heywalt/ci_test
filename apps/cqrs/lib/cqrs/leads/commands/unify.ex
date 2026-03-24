defmodule CQRS.Leads.Commands.Unify do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :city, String.t()
    field :enrichment_id, Ecto.UUID.t(), enforce: true
    field :enrichment_type, :best | :lesser | nil
    field :ptt, integer, default: 0
    field :state, String.t()
    field :street_1, String.t()
    field :street_2, String.t()
    field :zip, String.t()
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{
        id: :binary_id,
        city: :string,
        enrichment_id: :binary_id,
        enrichment_type: :any,
        ptt: :integer,
        state: :string,
        street_1: :string,
        street_2: :string,
        zip: :string
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :enrichment_id])
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
