defmodule WaltUi.Realtors.RealtorIdentity do
  @moduledoc """
  Schema for realtor identities, serving as the email-based deduplication anchor.

  Each identity represents a unique email address. Realtor records are linked
  to an identity via `realtor_identity_id`.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Realtors.RealtorRecord

  @type t :: %__MODULE__{}

  @required [:email]
  @optional []

  schema "realtor_identities" do
    field :email, :string

    has_many :records, RealtorRecord, foreign_key: :realtor_identity_id

    timestamps()
  end

  @doc false
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(identity \\ %__MODULE__{}, attrs) do
    identity
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:email)
  end
end
