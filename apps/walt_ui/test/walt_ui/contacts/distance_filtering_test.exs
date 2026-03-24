defmodule WaltUi.Contacts.DistanceFilteringTest do
  use Repo.DataCase

  import WaltUi.Factory

  alias WaltUi.Contacts

  describe "within_bounding_box/4" do
    test "finds contacts within bounding box" do
      user = insert(:user)

      # Create contacts with known coordinates
      austin_contact =
        insert(:contact,
          user_id: user.id,
          latitude: Decimal.new("30.2672"),
          longitude: Decimal.new("-97.7431"),
          city: "Austin"
        )

      dallas_contact =
        insert(:contact,
          user_id: user.id,
          latitude: Decimal.new("32.7767"),
          longitude: Decimal.new("-96.7970"),
          city: "Dallas"
        )

      # Search within 10 miles of Austin
      results =
        Contacts.within_bounding_box(user.id, 30.2672, -97.7431, 10)
        |> Repo.all()

      # Should find Austin contact but not Dallas contact
      contact_ids = Enum.map(results, & &1.id)
      assert austin_contact.id in contact_ids
      refute dallas_contact.id in contact_ids
    end

    test "only returns contacts for the specified user" do
      user1 = insert(:user)
      user2 = insert(:user)

      # Create contacts for both users in Austin area
      user1_contact =
        insert(:contact,
          user_id: user1.id,
          latitude: Decimal.new("30.2672"),
          longitude: Decimal.new("-97.7431")
        )

      user2_contact =
        insert(:contact,
          user_id: user2.id,
          latitude: Decimal.new("30.2672"),
          longitude: Decimal.new("-97.7431")
        )

      # Search for user1 contacts only
      results =
        Contacts.within_bounding_box(user1.id, 30.2672, -97.7431, 10)
        |> Repo.all()

      contact_ids = Enum.map(results, & &1.id)
      assert user1_contact.id in contact_ids
      refute user2_contact.id in contact_ids
    end

    test "excludes contacts without coordinates" do
      user = insert(:user)

      # Contact with coordinates
      geocoded_contact =
        insert(:contact,
          user_id: user.id,
          latitude: Decimal.new("30.2672"),
          longitude: Decimal.new("-97.7431")
        )

      # Contact without coordinates
      non_geocoded_contact =
        insert(:contact,
          user_id: user.id,
          latitude: nil,
          longitude: nil
        )

      results =
        Contacts.within_bounding_box(user.id, 30.2672, -97.7431, 10)
        |> Repo.all()

      contact_ids = Enum.map(results, & &1.id)
      assert geocoded_contact.id in contact_ids
      refute non_geocoded_contact.id in contact_ids
    end
  end
end
