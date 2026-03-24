defmodule WaltUi.Realtors.RealtorPhoneNumber do
  @moduledoc """
  Schema for realtor phone numbers.

  A phone number is a standalone lookup record identified by its `(number, type)`
  pair. Phone numbers are linked to `RealtorRecord`s via the
  `realtor_records_phone_numbers` join table, enabling many-to-many relationships:
  a record can have multiple phone numbers and a phone number can belong to
  multiple records.

  The number is stored as a normalized 10-digit string via the `TenDigitPhone` type.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Realtors.RealtorRecord

  @type t :: %__MODULE__{}

  @required [:number, :type]
  @optional []

  schema "realtor_phone_numbers" do
    field :number, TenDigitPhone
    field :type, :string

    many_to_many :records, RealtorRecord, join_through: "realtor_records_phone_numbers"

    timestamps()
  end

  @doc false
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(phone_number \\ %__MODULE__{}, attrs) do
    phone_number
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_inclusion(:type, ["cell", "office"])
    |> unique_constraint([:number, :type], name: "realtor_phone_numbers_number_type_idx")
  end
end
