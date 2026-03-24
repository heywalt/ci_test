defmodule WaltUi.Realtors.RealtorPhoneNumberTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Realtors.RealtorPhoneNumber

  describe "changeset/2" do
    test "valid with number and type cell" do
      attrs = %{number: "5551234567", type: "cell"}

      changeset = RealtorPhoneNumber.changeset(%RealtorPhoneNumber{}, attrs)

      assert changeset.valid?
    end

    test "valid with number and type office" do
      attrs = %{number: "5551234567", type: "office"}

      changeset = RealtorPhoneNumber.changeset(%RealtorPhoneNumber{}, attrs)

      assert changeset.valid?
    end

    test "invalid with missing number" do
      attrs = %{type: "cell"}

      changeset = RealtorPhoneNumber.changeset(%RealtorPhoneNumber{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:number)
    end

    test "invalid with missing type" do
      attrs = %{number: "5551234567"}

      changeset = RealtorPhoneNumber.changeset(%RealtorPhoneNumber{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:type)
    end

    test "invalid with unsupported type" do
      attrs = %{number: "5551234567", type: "fax"}

      changeset = RealtorPhoneNumber.changeset(%RealtorPhoneNumber{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:type)
    end

    test "normalizes phone number via TenDigitPhone" do
      attrs = %{number: "(703) 216-2139", type: "cell"}

      changeset = RealtorPhoneNumber.changeset(%RealtorPhoneNumber{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :number) == "7032162139"
    end
  end

  describe "unique constraint" do
    test "inserting two phone numbers with same number and type raises unique constraint error" do
      insert(:realtor_phone_number, number: "5551234567", type: "cell")

      {:error, changeset} =
        %RealtorPhoneNumber{}
        |> RealtorPhoneNumber.changeset(%{number: "5551234567", type: "cell"})
        |> Repo.insert()

      assert errors_on(changeset) |> Map.has_key?(:number)
    end

    test "inserting same number with different type succeeds" do
      insert(:realtor_phone_number, number: "5551234567", type: "cell")

      {:ok, _phone} =
        %RealtorPhoneNumber{}
        |> RealtorPhoneNumber.changeset(%{number: "5551234567", type: "office"})
        |> Repo.insert()
    end
  end
end
