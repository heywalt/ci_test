defmodule WaltUi.Realtors.RealtorRecordPhoneNumberTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Realtors.RealtorRecordPhoneNumber

  describe "changeset/2" do
    test "valid with record_id and phone_number_id" do
      record = insert(:realtor_record)
      phone = insert(:realtor_phone_number)

      attrs = %{
        realtor_record_id: record.id,
        realtor_phone_number_id: phone.id
      }

      changeset = RealtorRecordPhoneNumber.changeset(%RealtorRecordPhoneNumber{}, attrs)

      assert changeset.valid?
    end

    test "invalid with missing realtor_record_id" do
      phone = insert(:realtor_phone_number)

      attrs = %{realtor_phone_number_id: phone.id}

      changeset = RealtorRecordPhoneNumber.changeset(%RealtorRecordPhoneNumber{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:realtor_record_id)
    end

    test "invalid with missing realtor_phone_number_id" do
      record = insert(:realtor_record)

      attrs = %{realtor_record_id: record.id}

      changeset = RealtorRecordPhoneNumber.changeset(%RealtorRecordPhoneNumber{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:realtor_phone_number_id)
    end
  end

  describe "unique constraint" do
    test "inserting duplicate record_id and phone_number_id raises unique constraint error" do
      record = insert(:realtor_record)
      phone = insert(:realtor_phone_number)

      insert(:realtor_record_phone_number, record: record, phone_number: phone)

      {:error, changeset} =
        %RealtorRecordPhoneNumber{}
        |> RealtorRecordPhoneNumber.changeset(%{
          realtor_record_id: record.id,
          realtor_phone_number_id: phone.id
        })
        |> Repo.insert()

      assert errors_on(changeset) |> Map.has_key?(:realtor_record_id)
    end
  end
end
