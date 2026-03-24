defmodule WaltUi.Projections.PossibleAddress do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [:id, :enrichment_id, :street_1, :city, :state, :zip]
  @optional [:street_2]

  @derive {Jason.Encoder, only: [:id, :street_1, :street_2, :city, :state, :zip]}
  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "projection_possible_addresses" do
    field :enrichment_id, :binary_id
    field :street_1, :string
    field :street_2, :string
    field :city, :string
    field :state, :string
    field :zip, :string

    timestamps()
  end

  def changeset(address \\ %__MODULE__{}, attrs) do
    address
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end
end
