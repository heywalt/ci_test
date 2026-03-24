defmodule WaltUi.Handlers.GeocodeOnAddressChangeTest do
  use Repo.DataCase, async: false
  use Oban.Testing, repo: Repo

  import WaltUi.Factory

  alias CQRS.Leads.Events.LeadUnified
  alias CQRS.Leads.Events.LeadUpdated
  alias WaltUi.Geocoding.GeocodeContactAddressJob
  alias WaltUi.Handlers.GeocodeOnAddressChange

  describe "handle/2 with LeadUpdated - premium restrictions" do
    test "schedules geocoding job for premium user when address fields updated" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        premium_user = insert(:user, tier: :premium)
        contact = insert(:contact, user_id: premium_user.id)

        event = %LeadUpdated{
          id: contact.id,
          user_id: premium_user.id,
          attrs: %{
            "street_1" => "123 Main St",
            "city" => "Columbus",
            "state" => "OH",
            "zip" => "43215"
          },
          metadata: [],
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }

        assert :ok = GeocodeOnAddressChange.handle(event, %{})

        # Verify job was enqueued
        assert_enqueued(
          worker: GeocodeContactAddressJob,
          args: %{contact_id: contact.id, user_id: premium_user.id}
        )
      end)
    end

    test "does not schedule geocoding job for freemium user when address fields updated" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        freemium_user = insert(:user, tier: :freemium)
        contact = insert(:contact, user_id: freemium_user.id)

        event = %LeadUpdated{
          id: contact.id,
          user_id: freemium_user.id,
          attrs: %{
            "street_1" => "123 Main St",
            "city" => "Columbus",
            "state" => "OH",
            "zip" => "43215"
          },
          metadata: [],
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }

        assert :ok = GeocodeOnAddressChange.handle(event, %{})

        # Verify no job was enqueued
        refute_enqueued(worker: GeocodeContactAddressJob)
      end)
    end

    test "does not schedule geocoding when no address fields updated" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        premium_user = insert(:user, tier: :premium)
        contact = insert(:contact, user_id: premium_user.id)

        event = %LeadUpdated{
          id: contact.id,
          user_id: premium_user.id,
          attrs: %{
            "first_name" => "John",
            "last_name" => "Doe"
          },
          metadata: [],
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }

        assert :ok = GeocodeOnAddressChange.handle(event, %{})

        # Verify no job was enqueued
        refute_enqueued(worker: GeocodeContactAddressJob)
      end)
    end
  end

  describe "handle/2 with LeadUnified - premium restrictions" do
    test "schedules geocoding job for premium user when address data present" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        premium_user = insert(:user, tier: :premium)
        contact = insert(:contact, user_id: premium_user.id)

        event = %LeadUnified{
          id: contact.id,
          enrichment_id: Ecto.UUID.generate(),
          street_1: "456 Oak Ave",
          city: "Columbus",
          state: "OH",
          zip: "43215",
          ptt: 50,
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }

        assert :ok = GeocodeOnAddressChange.handle(event, %{})

        # Verify job was enqueued
        assert_enqueued(
          worker: GeocodeContactAddressJob,
          args: %{contact_id: contact.id, user_id: premium_user.id}
        )
      end)
    end

    test "does not schedule geocoding job for freemium user when address data present" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        freemium_user = insert(:user, tier: :freemium)
        contact = insert(:contact, user_id: freemium_user.id)

        event = %LeadUnified{
          id: contact.id,
          enrichment_id: Ecto.UUID.generate(),
          street_1: "456 Oak Ave",
          city: "Columbus",
          state: "OH",
          zip: "43215",
          ptt: 50,
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }

        assert :ok = GeocodeOnAddressChange.handle(event, %{})

        # Verify no job was enqueued
        refute_enqueued(worker: GeocodeContactAddressJob)
      end)
    end

    test "does not schedule geocoding when no geocodable address" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        premium_user = insert(:user, tier: :premium)
        contact = insert(:contact, user_id: premium_user.id)

        event = %LeadUnified{
          id: contact.id,
          enrichment_id: Ecto.UUID.generate(),
          street_1: nil,
          city: nil,
          state: "OH",
          zip: nil,
          ptt: 50,
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }

        assert :ok = GeocodeOnAddressChange.handle(event, %{})

        # Verify no job was enqueued
        refute_enqueued(worker: GeocodeContactAddressJob)
      end)
    end
  end
end
