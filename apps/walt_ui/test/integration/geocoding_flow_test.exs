defmodule WaltUi.Integration.GeocodingFlowTest do
  use WaltUi.CqrsCase, async: false
  use Mimic

  import AssertAsync
  import WaltUi.Factory
  import WaltUi.Helpers
  import Oban.Testing

  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias WaltUi.Projections.Contact

  @start_processes [
    WaltUi.ProcessManagers.UnificationManager,
    WaltUi.ProcessManagers.ContactEnrichmentManager,
    WaltUi.ProcessManagers.EnrichmentOrchestrationManager,
    WaltUi.Handlers.GeocodeOnAddressChange
  ]

  setup [:set_mimic_global, :verify_on_exit!]

  setup do
    # Configure providers for testing
    original_trestle_config = Application.get_env(:walt_ui, WaltUi.Trestle, [])
    Application.put_env(:walt_ui, WaltUi.Trestle, client: WaltUi.Enrichment.Trestle.Http)

    original_faraday_config = Application.get_env(:walt_ui, WaltUi.Faraday, [])
    Application.put_env(:walt_ui, WaltUi.Faraday, client: WaltUi.Enrichment.Faraday.Http)

    Enum.each(@start_processes, &start_supervised!/1)

    on_exit(fn ->
      Application.put_env(:walt_ui, WaltUi.Trestle, original_trestle_config)
      Application.put_env(:walt_ui, WaltUi.Faraday, original_faraday_config)
    end)

    :ok
  end

  describe "geocoding flow after enrichment" do
    test "geocodes contact address after enrichment completes" do
      with_testing_mode(:inline, fn ->
        # Setup test data
        user = insert(:user, tier: :premium)
        enrichment_id = UUID.uuid5(:oid, "5551234567")

        # Mock enrichment providers
        expect(WaltUi.Enrichment.Trestle.Http, :search_by_phone, fn phone, _opts ->
          assert phone == "5551234567"

          {:ok,
           %{
             "owners" => [
               %{
                 "firstname" => "John",
                 "lastname" => "Doe",
                 "phone" => "5551234567",
                 "current_addresses" => [
                   %{
                     "street_line_1" => "123 Main St",
                     "city" => "Austin",
                     "state_code" => "TX",
                     "postal_code" => "78701"
                   }
                 ]
               }
             ]
           }}
        end)

        expect(WaltUi.Enrichment.Faraday, :fetch_by_identity_sets, fn _id_sets ->
          {:ok, %{}}
        end)

        # Mock Google Maps Geocoding API
        expect(WaltUi.Geocoding, :geocode_address, fn address ->
          assert address.street_1 == "123 Main St"
          assert address.city == "Austin"
          assert address.state == "TX"
          assert address.zip == "78701"
          {:ok, {30.2672, -97.7431}}
        end)

        # Mock TypeSense operations
        stub(ExTypesense, :index_document, fn _index_data -> {:ok, %{}} end)
        stub(ExTypesense, :update_document, fn _update_data -> {:ok, %{}} end)

        # Create contact that will trigger enrichment
        contact =
          await_contact(
            first_name: "John",
            last_name: "Doe",
            phone: "5551234567",
            street_1: nil,
            city: nil,
            state: nil,
            zip: nil,
            latitude: nil,
            longitude: nil,
            user_id: user.id
          )

        # Wait for enrichment to complete and trigger geocoding
        assert_receive_event(
          CQRS,
          EnrichmentComposed,
          fn evt -> evt.id == enrichment_id end,
          fn _evt -> :ok end
        )

        # Assert contact was geocoded after enrichment
        assert_async do
          updated_contact = Repo.get(Contact, contact.id)
          assert updated_contact.street_1 == "123 Main St"
          assert updated_contact.city == "Austin"
          assert updated_contact.state == "TX"
          assert updated_contact.zip == "78701"

          # Check if geocoding happened
          if updated_contact.latitude && updated_contact.longitude do
            assert Decimal.equal?(updated_contact.latitude, Decimal.new("30.2672"))
            assert Decimal.equal?(updated_contact.longitude, Decimal.new("-97.7431"))
          else
            flunk(
              "Contact was not geocoded - latitude: #{inspect(updated_contact.latitude)}, longitude: #{inspect(updated_contact.longitude)}"
            )
          end
        end
      end)
    end

    test "handles geocoding API failures gracefully" do
      with_testing_mode(:inline, fn ->
        # Setup test data
        user = insert(:user, tier: :premium)
        enrichment_id = UUID.uuid5(:oid, "5551234567")

        # Mock enrichment providers
        expect(WaltUi.Enrichment.Trestle.Http, :search_by_phone, fn _phone, _opts ->
          {:ok,
           %{
             "owners" => [
               %{
                 "firstname" => "John",
                 "lastname" => "Doe",
                 "phone" => "5551234567",
                 "current_addresses" => [
                   %{
                     "street_line_1" => "Invalid Address",
                     "city" => "Nowhere",
                     "state_code" => "XX",
                     "postal_code" => "00000"
                   }
                 ]
               }
             ]
           }}
        end)

        expect(WaltUi.Enrichment.Faraday, :fetch_by_identity_sets, fn _id_sets ->
          {:ok, %{}}
        end)

        # Mock Google Maps API to return error
        expect(WaltUi.Geocoding, :geocode_address, fn _address ->
          {:error, :zero_results}
        end)

        # Mock TypeSense operations
        stub(ExTypesense, :index_document, fn _index_data -> {:ok, %{}} end)
        stub(ExTypesense, :update_document, fn _update_data -> {:ok, %{}} end)

        # Create contact
        contact =
          await_contact(
            first_name: "John",
            last_name: "Doe",
            phone: "5551234567",
            user_id: user.id
          )

        # Wait for enrichment to complete
        assert_receive_event(
          CQRS,
          EnrichmentComposed,
          fn evt -> evt.id == enrichment_id end,
          fn _evt -> :ok end
        )

        # Assert contact address was updated but coordinates remain nil on geocoding failure
        assert_async do
          updated_contact = Repo.get(Contact, contact.id)
          assert updated_contact.street_1 == "Invalid Address"
          assert updated_contact.city == "Nowhere"
          assert updated_contact.state == "XX"
          assert updated_contact.zip == "00000"
          assert is_nil(updated_contact.latitude)
          assert is_nil(updated_contact.longitude)
        end
      end)
    end
  end

  describe "distance filtering" do
    test "finds contacts within bounding box" do
      user = insert(:user, tier: :premium)

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
        WaltUi.Contacts.within_bounding_box(user.id, 30.2672, -97.7431, 10)
        |> Repo.all()

      # Should find Austin contact but not Dallas contact
      contact_ids = Enum.map(results, & &1.id)
      assert austin_contact.id in contact_ids
      refute dallas_contact.id in contact_ids
    end
  end
end
