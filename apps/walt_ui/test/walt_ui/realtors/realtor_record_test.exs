defmodule WaltUi.Realtors.RealtorRecordTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Realtors.RealtorRecord

  describe "changeset/2" do
    test "valid with required fields" do
      identity = insert(:realtor_identity)
      attrs = %{realtor_identity_id: identity.id, content_hash: "abc123"}

      changeset = RealtorRecord.changeset(%RealtorRecord{}, attrs)

      assert changeset.valid?
    end

    test "valid with all fields" do
      identity = insert(:realtor_identity)
      brokerage = insert(:realtor_brokerage)
      address = insert(:realtor_address)
      association = insert(:realtor_association)

      attrs = %{
        realtor_identity_id: identity.id,
        content_hash: "abc123",
        first_name: "Jane",
        last_name: "Doe",
        license_type: "Broker",
        license_number: "BR-12345",
        brokerage_id: brokerage.id,
        address_id: address.id,
        association_id: association.id
      }

      changeset = RealtorRecord.changeset(%RealtorRecord{}, attrs)

      assert changeset.valid?
    end

    test "invalid with missing realtor_identity_id" do
      changeset = RealtorRecord.changeset(%RealtorRecord{}, %{content_hash: "abc123"})

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:realtor_identity_id)
    end

    test "optional fields can all be nil" do
      identity = insert(:realtor_identity)

      attrs = %{
        realtor_identity_id: identity.id,
        content_hash: "abc123",
        first_name: nil,
        last_name: nil,
        license_type: nil,
        license_number: nil,
        brokerage_id: nil,
        address_id: nil,
        association_id: nil
      }

      changeset = RealtorRecord.changeset(%RealtorRecord{}, attrs)

      assert changeset.valid?
    end
  end

  describe "content hash" do
    test "changeset automatically computes content_hash" do
      identity = insert(:realtor_identity)

      attrs = %{
        realtor_identity_id: identity.id,
        first_name: "Jane",
        last_name: "Doe"
      }

      changeset = RealtorRecord.changeset(%RealtorRecord{}, attrs)

      assert changeset.valid?
      content_hash = Ecto.Changeset.get_change(changeset, :content_hash)
      assert is_binary(content_hash)
      assert String.length(content_hash) == 64
    end

    test "same attrs produce same content_hash" do
      identity = insert(:realtor_identity)

      attrs = %{
        realtor_identity_id: identity.id,
        first_name: "Jane",
        last_name: "Doe",
        license_type: "Broker",
        license_number: "BR-12345"
      }

      changeset_1 = RealtorRecord.changeset(%RealtorRecord{}, attrs)
      changeset_2 = RealtorRecord.changeset(%RealtorRecord{}, attrs)

      hash_1 = Ecto.Changeset.get_change(changeset_1, :content_hash)
      hash_2 = Ecto.Changeset.get_change(changeset_2, :content_hash)

      assert hash_1 == hash_2
    end

    test "different attrs produce different content_hash" do
      identity = insert(:realtor_identity)

      attrs_1 = %{
        realtor_identity_id: identity.id,
        first_name: "Jane",
        last_name: "Doe"
      }

      attrs_2 = %{
        realtor_identity_id: identity.id,
        first_name: "John",
        last_name: "Smith"
      }

      changeset_1 = RealtorRecord.changeset(%RealtorRecord{}, attrs_1)
      changeset_2 = RealtorRecord.changeset(%RealtorRecord{}, attrs_2)

      hash_1 = Ecto.Changeset.get_change(changeset_1, :content_hash)
      hash_2 = Ecto.Changeset.get_change(changeset_2, :content_hash)

      refute hash_1 == hash_2
    end

    test "inserting two records with same identity and same content raises unique constraint error" do
      identity = insert(:realtor_identity)

      attrs = %{
        realtor_identity_id: identity.id,
        first_name: "Jane",
        last_name: "Doe"
      }

      {:ok, _record_1} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(attrs)
        |> Repo.insert()

      {:error, changeset} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(attrs)
        |> Repo.insert()

      assert errors_on(changeset) |> Map.has_key?(:realtor_identity_id)
    end

    test "inserting two records with same identity but different content succeeds" do
      identity = insert(:realtor_identity)

      attrs_1 = %{
        realtor_identity_id: identity.id,
        first_name: "Jane",
        last_name: "Doe"
      }

      attrs_2 = %{
        realtor_identity_id: identity.id,
        first_name: "Jane",
        last_name: "Smith"
      }

      {:ok, _record_1} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(attrs_1)
        |> Repo.insert()

      {:ok, _record_2} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(attrs_2)
        |> Repo.insert()
    end
  end

  describe "many_to_many phone_numbers" do
    test "record can be associated with phone numbers via join table" do
      record = insert(:realtor_record)
      phone_1 = insert(:realtor_phone_number, number: "5551234567", type: "cell")
      phone_2 = insert(:realtor_phone_number, number: "5559876543", type: "office")

      insert(:realtor_record_phone_number, record: record, phone_number: phone_1)
      insert(:realtor_record_phone_number, record: record, phone_number: phone_2)

      loaded_record = Repo.preload(record, :phone_numbers)

      assert length(loaded_record.phone_numbers) == 2

      phone_numbers = Enum.map(loaded_record.phone_numbers, & &1.number)
      assert "5551234567" in phone_numbers
      assert "5559876543" in phone_numbers
    end
  end
end
