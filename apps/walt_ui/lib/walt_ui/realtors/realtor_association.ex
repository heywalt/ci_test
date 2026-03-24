defmodule WaltUi.Realtors.RealtorAssociation do
  @moduledoc """
  Schema for realtor associations (e.g., regional boards of realtors).

  Each association has a unique case-insensitive name. Realtor records may
  optionally belong to an association.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Realtors.RealtorRecord

  @type t :: %__MODULE__{}

  @required [:name]
  @optional []

  schema "realtor_associations" do
    field :name, :string

    has_many :records, RealtorRecord, foreign_key: :association_id

    timestamps()
  end

  @doc false
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(association \\ %__MODULE__{}, attrs) do
    association
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:name)
  end
end
