defmodule WaltUi.Projections.Trestle.Address do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  embedded_schema do
    field :street_1, :string
    field :street_2, :string
    field :city, :string
    field :state, :string
    field :zip, :string
  end

  def changeset(address \\ %__MODULE__{}, attrs) do
    address
    |> cast(attrs, [:street_1, :street_2, :city, :state, :zip])
    |> validate_required([:street_1, :city, :state, :zip])
  end
end
