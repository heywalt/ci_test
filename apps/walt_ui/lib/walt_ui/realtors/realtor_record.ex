defmodule WaltUi.Realtors.RealtorRecord do
  @moduledoc """
  Schema for realtor records.

  A realtor record represents a single row of agent data. It must belong to a
  `RealtorIdentity` (the email anchor) and may optionally reference a brokerage,
  address, and association.

  ## Content Hash

  The `content_hash` field is a SHA-256 digest of the record's content fields,
  used with `realtor_identity_id` to prevent duplicate rows. The hash is
  computed from:

    * `first_name`
    * `last_name`
    * `license_type`
    * `license_number`
    * `brokerage_id`
    * `address_id`
    * `association_id`

  If the set of meaningful fields changes (e.g., a new field is added to the
  schema), the hash computation in `@hash_fields` must be updated accordingly.
  Existing records will NOT be automatically rehashed — a backfill migration
  would be needed to recompute hashes for existing rows.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Realtors.RealtorAddress
  alias WaltUi.Realtors.RealtorAssociation
  alias WaltUi.Realtors.RealtorBrokerage
  alias WaltUi.Realtors.RealtorIdentity
  alias WaltUi.Realtors.RealtorPhoneNumber

  @type t :: %__MODULE__{}

  @castable [
    :realtor_identity_id,
    :first_name,
    :last_name,
    :license_type,
    :license_number,
    :brokerage_id,
    :address_id,
    :association_id
  ]

  @required [:realtor_identity_id, :content_hash]

  @hash_fields [
    :first_name,
    :last_name,
    :license_type,
    :license_number,
    :brokerage_id,
    :address_id,
    :association_id
  ]

  schema "realtor_records" do
    field :first_name, :string
    field :last_name, :string
    field :license_type, :string
    field :license_number, :string
    field :content_hash, :string

    belongs_to :identity, RealtorIdentity, foreign_key: :realtor_identity_id
    belongs_to :brokerage, RealtorBrokerage
    belongs_to :address, RealtorAddress
    belongs_to :association, RealtorAssociation

    many_to_many :phone_numbers, RealtorPhoneNumber, join_through: "realtor_records_phone_numbers"

    timestamps()
  end

  @doc false
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(record \\ %__MODULE__{}, attrs) do
    record
    |> cast(attrs, @castable)
    |> compute_content_hash()
    |> validate_required(@required)
    |> unique_constraint([:realtor_identity_id, :content_hash],
      name: "realtor_records_identity_content_hash_idx"
    )
    |> foreign_key_constraint(:realtor_identity_id)
    |> foreign_key_constraint(:brokerage_id)
    |> foreign_key_constraint(:address_id)
    |> foreign_key_constraint(:association_id)
  end

  defp compute_content_hash(changeset) do
    if changeset.valid? do
      hash =
        @hash_fields
        |> Enum.map_join("|", fn field ->
          changeset
          |> Ecto.Changeset.get_field(field)
          |> to_string()
        end)
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      Ecto.Changeset.put_change(changeset, :content_hash, hash)
    else
      changeset
    end
  end
end
