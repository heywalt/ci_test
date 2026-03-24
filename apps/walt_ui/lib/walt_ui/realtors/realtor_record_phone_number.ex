defmodule WaltUi.Realtors.RealtorRecordPhoneNumber do
  @moduledoc """
  Join schema linking realtor records to phone numbers.

  This enables a many-to-many relationship: a record can have multiple phone
  numbers, and a phone number can belong to multiple records.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Realtors.RealtorPhoneNumber
  alias WaltUi.Realtors.RealtorRecord

  @type t :: %__MODULE__{}

  @required [:realtor_record_id, :realtor_phone_number_id]

  schema "realtor_records_phone_numbers" do
    belongs_to :record, RealtorRecord, foreign_key: :realtor_record_id
    belongs_to :phone_number, RealtorPhoneNumber, foreign_key: :realtor_phone_number_id

    timestamps()
  end

  @doc false
  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(record_phone_number \\ %__MODULE__{}, attrs) do
    record_phone_number
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> unique_constraint([:realtor_record_id, :realtor_phone_number_id],
      name: "realtor_records_phone_numbers_unique_idx"
    )
    |> foreign_key_constraint(:realtor_record_id)
    |> foreign_key_constraint(:realtor_phone_number_id)
  end
end
