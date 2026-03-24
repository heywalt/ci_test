defmodule WaltUi.RealtorsTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Realtors
  alias WaltUi.Realtors.RealtorIdentity
  alias WaltUi.Realtors.RealtorPhoneNumber
  alias WaltUi.Realtors.RealtorRecord
  alias WaltUi.Realtors.RealtorRecordPhoneNumber

  @csv_headers "Email,First name,Last name,Brokerage,Address 1,Address 2,City,State,Zip,Cell Phone,Phone,License type,License number,Association"

  defp write_csv(rows) do
    path = Path.join(System.tmp_dir!(), "realtors_test_#{System.unique_integer([:positive])}.csv")
    content = [@csv_headers | rows] |> Enum.join("\n")
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp count(queryable), do: Repo.aggregate(queryable, :count)

  describe "import_csv/1" do
    test "basic import — creates identities, records, and lookup tables for 2 rows" do
      # Header order: Email,First name,Last name,Brokerage,Address 1,Address 2,City,State,Zip,Cell Phone,Phone,License type,License number,Association
      path =
        write_csv([
          "alice@example.com,Alice,Smith,Acme Realty,123 Main St,,Denver,CO,80202,5551234567,,Broker,BR-001,Denver Board",
          "bob@example.com,Bob,Jones,Prime Homes,456 Oak Ave,Suite 200,Boulder,CO,80301,,5559876543,Agent,AG-002,Boulder Board"
        ])

      assert {:ok, result} = Realtors.import_csv(path)

      assert result.rows_processed == 2

      assert count(RealtorIdentity) == 2
      assert count(RealtorRecord) == 2

      # Verify Alice's record
      alice_identity = Repo.get_by!(RealtorIdentity, email: "alice@example.com")

      alice_record =
        RealtorRecord
        |> Repo.get_by!(realtor_identity_id: alice_identity.id)
        |> Repo.preload([:brokerage, :address, :association, :phone_numbers])

      assert alice_record.first_name == "Alice"
      assert alice_record.last_name == "Smith"
      assert alice_record.license_type == "Broker"
      assert alice_record.license_number == "BR-001"
      assert alice_record.brokerage.name == "Acme Realty"
      assert alice_record.address.address_1 == "123 Main St"
      assert alice_record.address.city == "Denver"
      assert alice_record.address.state == "CO"
      assert alice_record.address.zip == "80202"
      assert alice_record.association.name == "Denver Board"
      assert length(alice_record.phone_numbers) == 1
      assert List.first(alice_record.phone_numbers).number == "5551234567"
      assert List.first(alice_record.phone_numbers).type == "cell"

      # Verify Bob's record
      bob_identity = Repo.get_by!(RealtorIdentity, email: "bob@example.com")

      bob_record =
        RealtorRecord
        |> Repo.get_by!(realtor_identity_id: bob_identity.id)
        |> Repo.preload([:brokerage, :address, :association, :phone_numbers])

      assert bob_record.first_name == "Bob"
      assert bob_record.last_name == "Jones"
      assert bob_record.brokerage.name == "Prime Homes"
      assert bob_record.address.address_1 == "456 Oak Ave"
      assert bob_record.address.address_2 == "Suite 200"
      assert length(bob_record.phone_numbers) == 1
      assert List.first(bob_record.phone_numbers).number == "5559876543"
      assert List.first(bob_record.phone_numbers).type == "office"
    end

    test "dedup — re-importing same file creates no new records" do
      path =
        write_csv([
          "alice@example.com,Alice,Smith,Acme Realty,123 Main St,,Denver,CO,80202,5551234567,,Broker,BR-001,Denver Board",
          "bob@example.com,Bob,Jones,Prime Homes,456 Oak Ave,,Boulder,CO,80301,,5559876543,Agent,AG-002,Boulder Board"
        ])

      assert {:ok, _result_1} = Realtors.import_csv(path)

      identity_count = count(RealtorIdentity)
      record_count = count(RealtorRecord)
      phone_count = count(RealtorPhoneNumber)

      assert {:ok, _result_2} = Realtors.import_csv(path)

      assert count(RealtorIdentity) == identity_count
      assert count(RealtorRecord) == record_count
      assert count(RealtorPhoneNumber) == phone_count
    end

    test "lookup table dedup — two rows sharing a brokerage create only one brokerage" do
      path =
        write_csv([
          "alice@example.com,Alice,Smith,Shared Brokerage,123 Main St,,Denver,CO,80202,,,Broker,BR-001,",
          "bob@example.com,Bob,Jones,Shared Brokerage,456 Oak Ave,,Boulder,CO,80301,,5559876543,Agent,AG-002,"
        ])

      assert {:ok, _result} = Realtors.import_csv(path)

      import Ecto.Query

      brokerage_count =
        Repo.aggregate(
          from(b in WaltUi.Realtors.RealtorBrokerage, where: b.name == "Shared Brokerage"),
          :count
        )

      assert brokerage_count == 1

      assert count(RealtorRecord) == 2
    end
  end

  describe "import_csv/1 phone number edge cases" do
    test "test 1: pre-existing record without phone, import adds phone" do
      identity = insert(:realtor_identity, email: "agent1@example.com")

      # Insert a record with no phone associations, using known content
      {:ok, record} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(%{
          realtor_identity_id: identity.id,
          first_name: "Jane",
          last_name: "Doe",
          license_type: "Broker",
          license_number: "BR-100"
        })
        |> Repo.insert()

      assert record |> Repo.preload(:phone_numbers) |> Map.get(:phone_numbers) |> length() == 0

      # Import CSV row matching that content hash but including a cell phone
      # Header: Email,First name,Last name,Brokerage,Address 1,Address 2,City,State,Zip,Cell Phone,Phone,License type,License number,Association
      path =
        write_csv([
          "agent1@example.com,Jane,Doe,,,,,,,5551112222,,Broker,BR-100,"
        ])

      assert {:ok, _result} = Realtors.import_csv(path)

      # No new record created (same content hash)
      assert count(RealtorRecord) == 1

      # Record is now associated with the phone number
      updated_record = Repo.preload(record, :phone_numbers, force: true)
      assert length(updated_record.phone_numbers) == 1
      assert List.first(updated_record.phone_numbers).number == "5551112222"
      assert List.first(updated_record.phone_numbers).type == "cell"
    end

    test "test 2: pre-existing record with phones, import has no phone" do
      identity = insert(:realtor_identity, email: "agent2@example.com")

      {:ok, record} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(%{
          realtor_identity_id: identity.id,
          first_name: "John",
          last_name: "Smith",
          license_type: "Agent",
          license_number: "AG-200"
        })
        |> Repo.insert()

      # Associate 2 phones with the record
      phone_1 = insert(:realtor_phone_number, number: "5551110001", type: "cell")
      phone_2 = insert(:realtor_phone_number, number: "5551110002", type: "office")
      insert(:realtor_record_phone_number, record: record, phone_number: phone_1)
      insert(:realtor_record_phone_number, record: record, phone_number: phone_2)

      # Import CSV row matching content hash but with no phone numbers
      path =
        write_csv([
          "agent2@example.com,John,Smith,,,,,,,,,Agent,AG-200,"
        ])

      assert {:ok, _result} = Realtors.import_csv(path)

      # No new record created
      assert count(RealtorRecord) == 1

      # Record still has both phones
      updated_record = Repo.preload(record, :phone_numbers, force: true)
      assert length(updated_record.phone_numbers) == 2
    end

    test "test 3: pre-existing record with 3 phones, import has subset (2 phones)" do
      identity = insert(:realtor_identity, email: "agent3@example.com")

      {:ok, record} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(%{
          realtor_identity_id: identity.id,
          first_name: "Sara",
          last_name: "Connor"
        })
        |> Repo.insert()

      # Associate 3 phones
      phone_1 = insert(:realtor_phone_number, number: "5552220001", type: "cell")
      phone_2 = insert(:realtor_phone_number, number: "5552220002", type: "office")
      phone_3 = insert(:realtor_phone_number, number: "5552220003", type: "cell")
      insert(:realtor_record_phone_number, record: record, phone_number: phone_1)
      insert(:realtor_record_phone_number, record: record, phone_number: phone_2)
      insert(:realtor_record_phone_number, record: record, phone_number: phone_3)

      # Import CSV row with only 2 of the 3 phones
      path =
        write_csv([
          "agent3@example.com,Sara,Connor,,,,,,,5552220001,5552220002,,,"
        ])

      assert {:ok, _result} = Realtors.import_csv(path)

      # No new record created
      assert count(RealtorRecord) == 1

      # Record still has all 3 phones (additive, never removes)
      updated_record = Repo.preload(record, :phone_numbers, force: true)
      assert length(updated_record.phone_numbers) == 3
    end

    test "test 4: pre-existing record with 1 phone, import has that phone plus 1 new" do
      identity = insert(:realtor_identity, email: "agent4@example.com")

      {:ok, record} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(%{
          realtor_identity_id: identity.id,
          first_name: "Mike",
          last_name: "Ross"
        })
        |> Repo.insert()

      # Associate 1 existing cell phone
      existing_phone = insert(:realtor_phone_number, number: "5553330001", type: "cell")
      insert(:realtor_record_phone_number, record: record, phone_number: existing_phone)

      # Import CSV row with the existing cell phone plus a new office phone
      path =
        write_csv([
          "agent4@example.com,Mike,Ross,,,,,,,5553330001,5553330099,,,"
        ])

      assert {:ok, _result} = Realtors.import_csv(path)

      # No new record created
      assert count(RealtorRecord) == 1

      # Record now has both phones (existing cell re-linked + new office added)
      updated_record = Repo.preload(record, :phone_numbers, force: true)
      assert length(updated_record.phone_numbers) == 2

      phone_numbers = Enum.map(updated_record.phone_numbers, &{&1.number, &1.type})
      assert {"5553330001", "cell"} in phone_numbers
      assert {"5553330099", "office"} in phone_numbers
    end

    test "test 5: two different records sharing a phone number" do
      # Setup: record A with phone "5554440001" type "cell"
      identity_a = insert(:realtor_identity, email: "agentA@example.com")

      {:ok, record_a} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(%{
          realtor_identity_id: identity_a.id,
          first_name: "Agent",
          last_name: "Alpha"
        })
        |> Repo.insert()

      phone = insert(:realtor_phone_number, number: "5554440001", type: "cell")
      insert(:realtor_record_phone_number, record: record_a, phone_number: phone)

      # Import CSV row for a different identity with the same phone
      path =
        write_csv([
          "agentB@example.com,Agent,Beta,,,,,,,5554440001,,,,"
        ])

      assert {:ok, _result} = Realtors.import_csv(path)

      # New record B created (different identity)
      assert count(RealtorRecord) == 2

      # Only 1 phone_number row for "5554440001"/"cell"
      import Ecto.Query

      phone_count =
        Repo.aggregate(
          from(p in RealtorPhoneNumber, where: p.number == "5554440001" and p.type == "cell"),
          :count
        )

      assert phone_count == 1

      # Both records linked to the same phone number row
      join_count =
        Repo.aggregate(
          from(j in RealtorRecordPhoneNumber, where: j.realtor_phone_number_id == ^phone.id),
          :count
        )

      assert join_count == 2
    end

    test "test 6: same number, different type on same record" do
      identity = insert(:realtor_identity, email: "agent6@example.com")

      {:ok, record} =
        %RealtorRecord{}
        |> RealtorRecord.changeset(%{
          realtor_identity_id: identity.id,
          first_name: "Dana",
          last_name: "White"
        })
        |> Repo.insert()

      # Pre-existing: "5555550006" as "office"
      office_phone = insert(:realtor_phone_number, number: "5555550006", type: "office")
      insert(:realtor_record_phone_number, record: record, phone_number: office_phone)

      # Import CSV row with same number but as "cell"
      path =
        write_csv([
          "agent6@example.com,Dana,White,,,,,,,5555550006,,,,"
        ])

      assert {:ok, _result} = Realtors.import_csv(path)

      # No new record created
      assert count(RealtorRecord) == 1

      # 2 phone_number rows exist: same number but different types
      import Ecto.Query

      phone_count =
        Repo.aggregate(
          from(p in RealtorPhoneNumber, where: p.number == "5555550006"),
          :count
        )

      assert phone_count == 2

      # Record linked to both
      updated_record = Repo.preload(record, :phone_numbers, force: true)
      assert length(updated_record.phone_numbers) == 2

      types = Enum.map(updated_record.phone_numbers, & &1.type) |> Enum.sort()
      assert types == ["cell", "office"]
    end
  end
end
