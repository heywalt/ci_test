defmodule WaltUi.Realtors.RealtorBrokerage do
  @moduledoc """
  Schema for realtor brokerages.

  Each brokerage has a unique case-insensitive name. Realtor records may
  optionally belong to a brokerage.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Realtors.RealtorRecord

  @type t :: %__MODULE__{}

  @required [:name]
  @optional []

  schema "realtor_brokerages" do
    field :name, :string

    has_many :records, RealtorRecord, foreign_key: :brokerage_id

    timestamps()
  end

  @doc false
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(brokerage \\ %__MODULE__{}, attrs) do
    brokerage
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:name)
  end
end
