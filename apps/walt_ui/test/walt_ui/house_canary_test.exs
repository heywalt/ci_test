defmodule WaltUi.HouseCanaryTest do
  use Repo.DataCase, async: true

  import WaltUi.HouseCanaryFactory

  alias WaltUi.HouseCanary

  describe "find_by_address/5" do
    test "returns a property matching the address components" do
      property = insert(:property)

      result =
        HouseCanary.find_by_address(
          property.address_street_number,
          property.address_street_name,
          property.city,
          property.state,
          property.zipcode
        )

      assert result.id == property.id
    end

    test "returns nil when no property matches" do
      insert(:property)

      assert is_nil(HouseCanary.find_by_address("999", "Fake", "Nowhere", "XX", "00000"))
    end
  end

  describe "find_by_zipcode/1" do
    test "returns all properties in the given zipcode" do
      property1 = insert(:property, zipcode: "43215")
      property2 = insert(:property, zipcode: "43215")
      _other = insert(:property, zipcode: "90210")

      results = HouseCanary.find_by_zipcode("43215")

      result_ids = Enum.map(results, & &1.id)
      assert property1.id in result_ids
      assert property2.id in result_ids
      assert length(results) == 2
    end

    test "returns empty list when no properties match" do
      insert(:property, zipcode: "43215")

      assert HouseCanary.find_by_zipcode("00000") == []
    end
  end

  describe "find_by_owner_name/1" do
    test "returns properties matching the owner name" do
      property = insert(:property, owner_name: "SMITH JOHN")
      _other = insert(:property, owner_name: "DOE JANE")

      results = HouseCanary.find_by_owner_name("SMITH JOHN")

      assert length(results) == 1
      assert List.first(results).id == property.id
    end

    test "returns empty list when no properties match" do
      insert(:property, owner_name: "SMITH JOHN")

      assert HouseCanary.find_by_owner_name("NOBODY HERE") == []
    end
  end

  describe "find_by_borrower_last_name/1" do
    test "returns properties matching lien1 borrower last name" do
      property = insert(:property, lien1_borrower1_last_name: "SMITH")

      results = HouseCanary.find_by_borrower_last_name("SMITH")

      assert length(results) == 1
      assert List.first(results).id == property.id
    end

    test "returns properties matching lien2 borrower last name" do
      property =
        insert(:property,
          lien1_borrower1_last_name: "DOE",
          lien2_borrower1_last_name: "SMITH"
        )

      results = HouseCanary.find_by_borrower_last_name("SMITH")

      assert length(results) == 1
      assert List.first(results).id == property.id
    end

    test "returns empty list when no properties match" do
      insert(:property, lien1_borrower1_last_name: "SMITH")

      assert HouseCanary.find_by_borrower_last_name("NOBODY") == []
    end
  end

  describe "validate_address/6" do
    test "returns :high confidence when owner matches and is owner-occupied" do
      insert(:property,
        address_street_number: "123",
        address_street_name: "Main",
        city: "Columbus",
        state: "OH",
        zipcode: "43215",
        owner_name: "SMITH JOHN",
        owner_occupied_yn: "Y"
      )

      result =
        HouseCanary.validate_address("123", "Main", "Columbus", "OH", "43215", "John Smith")

      assert result.confidence == :high
      assert result.property != nil
    end

    test "returns :medium confidence when owner matches but not owner-occupied" do
      insert(:property,
        address_street_number: "123",
        address_street_name: "Main",
        city: "Columbus",
        state: "OH",
        zipcode: "43215",
        owner_name: "SMITH JOHN",
        owner_occupied_yn: "N"
      )

      result =
        HouseCanary.validate_address("123", "Main", "Columbus", "OH", "43215", "John Smith")

      assert result.confidence == :medium
      assert result.property != nil
    end

    test "returns :low confidence when property found but owner does not match" do
      insert(:property,
        address_street_number: "123",
        address_street_name: "Main",
        city: "Columbus",
        state: "OH",
        zipcode: "43215",
        owner_name: "DOE JANE",
        owner_occupied_yn: "Y"
      )

      result =
        HouseCanary.validate_address("123", "Main", "Columbus", "OH", "43215", "John Smith")

      assert result.confidence == :low
      assert result.property != nil
    end

    test "returns :none confidence when no property found" do
      result =
        HouseCanary.validate_address("999", "Fake", "Nowhere", "XX", "00000", "John Smith")

      assert result.confidence == :none
      assert result.property == nil
    end
  end
end
