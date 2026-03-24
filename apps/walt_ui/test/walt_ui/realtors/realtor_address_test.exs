defmodule WaltUi.Realtors.RealtorAddressTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Realtors.RealtorAddress

  describe "changeset/2" do
    test "valid with all fields" do
      attrs = %{
        address_1: "123 Main St",
        address_2: "Suite 100",
        city: "Richmond",
        state: "VA",
        zip: "23220"
      }

      changeset = RealtorAddress.changeset(%RealtorAddress{}, attrs)

      assert changeset.valid?
    end

    test "valid with only required fields" do
      attrs = %{address_1: "123 Main St", city: "Richmond", state: "VA"}
      changeset = RealtorAddress.changeset(%RealtorAddress{}, attrs)

      assert changeset.valid?
    end

    test "invalid with missing address_1" do
      attrs = %{city: "Richmond", state: "VA"}
      changeset = RealtorAddress.changeset(%RealtorAddress{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:address_1)
    end

    test "invalid with missing city" do
      attrs = %{address_1: "123 Main St", state: "VA"}
      changeset = RealtorAddress.changeset(%RealtorAddress{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:city)
    end

    test "invalid with missing state" do
      attrs = %{address_1: "123 Main St", city: "Richmond"}
      changeset = RealtorAddress.changeset(%RealtorAddress{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:state)
    end

    test "invalid with state longer than 2 characters" do
      attrs = %{address_1: "123 Main St", city: "Richmond", state: "Virginia"}
      changeset = RealtorAddress.changeset(%RealtorAddress{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:state)
    end

    test "invalid with zip longer than 10 characters" do
      attrs = %{address_1: "123 Main St", city: "Richmond", state: "VA", zip: "12345-67890"}
      changeset = RealtorAddress.changeset(%RealtorAddress{}, attrs)

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:zip)
    end

    test "unique constraint on compound address fields" do
      insert(:realtor_address,
        address_1: "123 Main St",
        address_2: "Suite 100",
        city: "Richmond",
        state: "VA",
        zip: "23220"
      )

      {:error, changeset} =
        %RealtorAddress{}
        |> RealtorAddress.changeset(%{
          address_1: "123 Main St",
          address_2: "Suite 100",
          city: "Richmond",
          state: "VA",
          zip: "23220"
        })
        |> Repo.insert()

      assert errors_on(changeset) |> Map.has_key?(:address_1)
    end

    test "unique constraint treats nil address_2 and zip as equal for uniqueness" do
      insert(:realtor_address,
        address_1: "123 Main St",
        address_2: nil,
        city: "Richmond",
        state: "VA",
        zip: nil
      )

      {:error, changeset} =
        %RealtorAddress{}
        |> RealtorAddress.changeset(%{
          address_1: "123 Main St",
          city: "Richmond",
          state: "VA"
        })
        |> Repo.insert()

      assert errors_on(changeset) |> Map.has_key?(:address_1)
    end
  end
end
