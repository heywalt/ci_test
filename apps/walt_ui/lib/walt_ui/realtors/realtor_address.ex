defmodule WaltUi.Realtors.RealtorAddress do
  @moduledoc """
  Schema for realtor addresses.

  Uniqueness is enforced via a compound index on all address fields, using
  COALESCE to treat NULL values as empty strings for uniqueness purposes.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Realtors.RealtorRecord

  @type t :: %__MODULE__{}

  @required [:address_1, :city, :state]
  @optional [:address_2, :zip]

  schema "realtor_addresses" do
    field :address_1, :string
    field :address_2, :string
    field :city, :string
    field :state, :string
    field :zip, :string

    has_many :records, RealtorRecord, foreign_key: :address_id

    timestamps()
  end

  @doc false
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(address \\ %__MODULE__{}, attrs) do
    address
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_length(:state, max: 2)
    |> validate_length(:zip, max: 10)
    |> unique_constraint([:address_1, :address_2, :city, :state, :zip],
      name: "realtor_addresses_compound_idx"
    )
  end
end
