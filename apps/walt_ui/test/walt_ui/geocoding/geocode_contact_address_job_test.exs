defmodule WaltUi.Geocoding.GeocodeContactAddressJobTest do
  use WaltUi.CqrsCase, async: false
  use Mimic

  import WaltUi.Factory
  import AssertAsync

  alias WaltUi.Geocoding
  alias WaltUi.Geocoding.GeocodeContactAddressJob
  alias WaltUi.Projections.Contact

  setup [:set_mimic_from_context, :verify_on_exit!]

  describe "process/1 - premium restrictions" do
    test "processes geocoding for premium user" do
      premium_user = insert(:user, tier: :premium)

      contact =
        await_contact(
          user_id: premium_user.id,
          street_1: "123 Main St",
          city: "Columbus",
          state: "OH",
          zip: "43215",
          latitude: nil,
          longitude: nil
        )

      # Mock the rate limiting to allow
      expect(Hammer, :check_rate, 2, fn _key, _period, _limit ->
        {:allow, 1}
      end)

      # Mock the geocoding service
      expect(Geocoding, :geocode_address, fn _contact ->
        {:ok, {39.9612, -82.9988}}
      end)

      job = %{args: %{contact_id: contact.id, user_id: premium_user.id}}

      assert :ok = GeocodeContactAddressJob.process(job)

      # Verify the contact was actually updated with coordinates
      assert_async do
        updated_contact = Repo.get(Contact, contact.id)
        assert Decimal.equal?(updated_contact.latitude, Decimal.new("39.9612"))
        assert Decimal.equal?(updated_contact.longitude, Decimal.new("-82.9988"))
      end
    end

    test "skips geocoding for freemium user" do
      freemium_user = insert(:user, tier: :freemium)

      contact =
        await_contact(
          user_id: freemium_user.id,
          street_1: "123 Main St",
          city: "Columbus",
          state: "OH",
          zip: "43215",
          latitude: nil,
          longitude: nil
        )

      # Should not call any geocoding functions
      reject(&Hammer.check_rate/3)
      reject(&Geocoding.geocode_address/1)

      job = %{args: %{contact_id: contact.id, user_id: freemium_user.id}}

      # Should return :ok to prevent retries
      assert :ok = GeocodeContactAddressJob.process(job)

      # Verify contact was not updated
      updated_contact = Repo.get(Contact, contact.id)
      assert is_nil(updated_contact.latitude)
      assert is_nil(updated_contact.longitude)
    end

    test "skips geocoding when user not found" do
      non_existent_user_id = Ecto.UUID.generate()
      user = insert(:user)
      contact = await_contact(user_id: user.id, latitude: nil, longitude: nil)

      # Should not call any geocoding functions
      reject(&Hammer.check_rate/3)
      reject(&Geocoding.geocode_address/1)

      job = %{args: %{contact_id: contact.id, user_id: non_existent_user_id}}

      # Should return :ok to prevent retries
      assert :ok = GeocodeContactAddressJob.process(job)

      # Verify contact was not updated
      updated_contact = Repo.get(Contact, contact.id)
      assert is_nil(updated_contact.latitude)
      assert is_nil(updated_contact.longitude)
    end

    test "respects rate limits for premium user" do
      premium_user = insert(:user, tier: :premium)
      contact = await_contact(user_id: premium_user.id)

      # Mock global rate limit exceeded
      expect(Hammer, :check_rate, fn "geocoding:global", _period, _limit ->
        {:deny, 45}
      end)

      job = %{args: %{contact_id: contact.id, user_id: premium_user.id}}

      # Should snooze when rate limited
      assert {:snooze, 1000} = GeocodeContactAddressJob.process(job)
    end

    test "respects per-user rate limits for premium user" do
      premium_user = insert(:user, tier: :premium)
      contact = await_contact(user_id: premium_user.id)

      # Mock global rate limit OK
      expect(Hammer, :check_rate, fn "geocoding:global", _period, _limit ->
        {:allow, 10}
      end)

      # Mock per-user rate limit exceeded
      expect(Hammer, :check_rate, fn "geocoding:" <> _user_id, _period, _limit ->
        {:deny, 15}
      end)

      job = %{args: %{contact_id: contact.id, user_id: premium_user.id}}

      # Should snooze when rate limited
      assert {:snooze, 1000} = GeocodeContactAddressJob.process(job)
    end
  end
end
