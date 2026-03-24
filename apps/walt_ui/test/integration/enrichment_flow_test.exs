defmodule WaltUi.Integration.EnrichmentFlowTest do
  use WaltUi.CqrsCase, async: false
  use Mimic

  import AssertAsync
  import WaltUi.Factory
  import WaltUi.Helpers
  import Oban.Testing

  alias CQRS.Enrichments.Commands.Jitter
  alias CQRS.Enrichments.Commands.Reset
  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Enrichments.Events.EnrichmentReset
  alias CQRS.Enrichments.Events.Jittered
  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias CQRS.Enrichments.Events.ProviderEnrichmentRequested
  alias CQRS.Leads.Events.LeadUnified
  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.ContactShowcase
  alias WaltUi.Projections.Enrichment
  alias WaltUi.Projections.Faraday
  alias WaltUi.Projections.Trestle

  @start_processes [
    WaltUi.Handlers.Search,
    WaltUi.ProcessManagers.ContactEnrichmentManager,
    WaltUi.ProcessManagers.EnrichmentOrchestrationManager,
    WaltUi.ProcessManagers.UnificationManager
  ]

  setup [:set_mimic_global, :verify_on_exit!]

  setup do
    # Configure providers to use real HTTP clients (that can be mocked) instead of dummy clients
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

  describe "composable enrichment flow" do
    test "complete happy path with age selection logic" do
      with_testing_mode(:inline, fn ->
        # Start the EnrichmentResetManager for this test
        start_supervised!(WaltUi.ProcessManagers.EnrichmentResetManager)

        # Setup test data
        user = insert(:user)
        enrichment_id = UUID.uuid5(:oid, "5551234567")

        # Mock Trestle API to return age range and contact data
        expect(WaltUi.Enrichment.Trestle.Http, :search_by_phone, fn phone, _opts ->
          assert phone == "5551234567"

          {:ok,
           %{
             "owners" => [
               %{
                 "firstname" => "John",
                 "lastname" => "Doe",
                 "age_range" => "25-34",
                 "phone" => "5551234567",
                 "emails" => ["john.doe@example.com"],
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

        # Mock Faraday API with high-quality match and different age
        expect(WaltUi.Enrichment.Faraday, :fetch_by_identity_sets, fn id_sets ->
          assert Enum.any?(id_sets, fn set -> set.phone == "5551234567" end)

          {:ok,
           %{
             "match_type" => "address_full_name",
             "fdy_attribute_fig_age" => 35,
             "person_first_name" => "John",
             "person_last_name" => "Doe",
             "fdy_attribute_fig_household_income" => 75_000,
             "fdy_attribute_fig_homeowner_status" => "Probable Renter",
             "fdy_outcome_2cac2e5e_27d4_4045_99ef_0338f007b8e6_propensity_probability" => 0.85,
             "person_home_address1" => "123 Main St",
             "person_home_city" => "Austin",
             "person_home_state" => "TX",
             "person_home_zip" => "78701"
           }}
        end)

        # Mock TypeSense index - will be called once for LeadCreated event from await_contact
        stub(ExTypesense, :index_document, fn _index_data ->
          {:ok, %{}}
        end)

        # Mock TypeSense update - will be called once after final composition
        expect(ExTypesense, :update_document, fn update_data ->
          assert update_data.collection_name == "contacts"
          # assert update_data.id == contact.id
          assert update_data.city == "Austin"
          assert update_data.state == "TX"
          assert update_data.street_1 == "123 Main St"
          assert update_data.zip == "78701"

          # Move Score will be 68 (with Faraday + renter reduction)
          assert update_data.ptt == 68
          assert update_data.updated_at

          {:ok, %{}}
        end)

        contact =
          await_contact(
            avatar: nil,
            city: nil,
            email: nil,
            first_name: "John",
            last_name: "Doen",
            phone: "5551234567",
            ptt: nil,
            state: nil,
            street_1: nil,
            user_id: user.id,
            zip: nil
          )

        # Assert Trestle is requested
        assert_receive_event(
          CQRS,
          ProviderEnrichmentRequested,
          fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
          fn evt -> assert evt.contact_data.phone == "5551234567" end
        )

        assert_receive_event(
          CQRS,
          ProviderEnrichmentRequested,
          fn evt -> evt.id == enrichment_id && evt.provider_type == "faraday" end,
          fn evt -> assert evt.contact_data.phone == "5551234567" end
        )

        # Assert final composition with age selection logic - the system should automatically:
        # 1. Run Trestle job (mocked HTTP call)
        # 2. Emit ProviderEnrichmentCompleted event
        # 3. Trigger Faraday job after Trestle success
        # 4. Emit ProviderEnrichmentCompleted for Faraday
        # 5. Trigger composition
        # 6. Emit EnrichmentComposed with final data
        assert_receive_event(
          CQRS,
          EnrichmentComposed,
          fn evt ->
            evt.id == enrichment_id && Map.has_key?(evt.provider_scores, "faraday") &&
              Map.has_key?(evt.provider_scores, "trestle")
          end,
          fn evt ->
            # Verify age selection: Faraday's age (35) wins over Trestle's age_range due to address_full_name match
            assert evt.composed_data.age == 35
            assert evt.data_sources.age == "faraday"

            # Verify other composed data
            assert evt.composed_data.first_name == "John"
            assert evt.composed_data.last_name == "Doe"
            assert evt.composed_data.household_income == 75_000
            # Move Score adjusted: 85 * 0.8 (renter reduction) = 68
            assert evt.composed_data.ptt == 68
            assert evt.composed_data.homeowner_status == "Probable Renter"
            assert evt.phone == "5551234567"

            # Verify provider scores
            assert evt.provider_scores["faraday"] > 0
            assert evt.provider_scores["trestle"] > 0
          end
        )

        # Verify enrichment projection updated
        assert_async do
          assert enrichment = Repo.get(Enrichment, enrichment_id)
          # Formatted as age range
          assert enrichment.age == "35-44"
          assert enrichment.household_income == "$70k+"
          assert enrichment.full_name == "John Doe"
        end

        assert_receive_event(
          CQRS,
          LeadUnified,
          fn evt -> evt.id == contact.id end,
          fn evt -> assert evt.ptt == 68 end
        )

        # Verify contact projection updated
        assert_async sleep: 500 do
          updated_contact = Repo.get(Contact, contact.id)
          assert updated_contact.enrichment_id == enrichment_id
          assert updated_contact.street_1 == "123 Main St"
          assert updated_contact.city == "Austin"
          assert updated_contact.state == "TX"
          assert updated_contact.zip == "78701"
          assert updated_contact.ptt == 68
        end

        # Test enrichment reset flow
        # First, trigger Jitter to create additional projection
        jitter_cmd = %Jitter{
          id: enrichment_id,
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        }

        :ok = CQRS.dispatch(jitter_cmd)

        # Assert Jittered event received
        assert_receive_event(
          CQRS,
          Jittered,
          fn evt -> evt.id == enrichment_id end,
          fn evt ->
            assert evt.id == enrichment_id
            # The score should be jittered from the original Move Score of 85
            assert evt.score > 0
            assert %NaiveDateTime{} = evt.timestamp
          end
        )

        # Verify all projections exist before reset
        assert_async do
          # All enrichment projections should exist
          assert Repo.get(Enrichment, enrichment_id)
          assert Repo.get(Faraday, enrichment_id)
          assert Repo.get(Trestle, enrichment_id)
          assert Repo.get(WaltUi.Projections.Jitter, enrichment_id)

          # Contact should have enrichment_id
          contact = Repo.get(Contact, contact.id)
          assert contact.enrichment_id == enrichment_id

          # ContactShowcase should exist for enriched contact
          assert Repo.get_by(ContactShowcase, contact_id: contact.id)
        end

        # Execute Reset command
        reset_cmd = Reset.new(%{id: enrichment_id})
        :ok = CQRS.dispatch(reset_cmd)

        # Assert EnrichmentReset event received
        assert_receive_event(
          CQRS,
          EnrichmentReset,
          fn evt -> evt.id == enrichment_id end,
          fn evt ->
            assert evt.id == enrichment_id
            assert %NaiveDateTime{} = evt.timestamp
          end
        )

        # Verify complete data purge
        assert_async do
          # Contact enrichment_id should be cleared
          contact = Repo.get(Contact, contact.id)
          assert is_nil(contact.enrichment_id)

          # All enrichment projections should be deleted
          assert is_nil(Repo.get(Enrichment, enrichment_id))
          assert is_nil(Repo.get(Faraday, enrichment_id))
          assert is_nil(Repo.get(Trestle, enrichment_id))
          assert is_nil(Repo.get(WaltUi.Projections.Jitter, enrichment_id))

          # ContactShowcase should be deleted
          refute Repo.get_by(ContactShowcase, contact_id: contact.id)
        end
      end)
    end

    test "Trestle failure blocks pipeline and prevents composition" do
      with_testing_mode(:inline, fn ->
        # Setup test data
        user = insert(:user)
        enrichment_id = UUID.uuid5(:oid, "5551234567")

        # Mock Trestle API to fail
        expect(WaltUi.Enrichment.Trestle.Http, :search_by_phone, fn phone, _opts ->
          assert phone == "5551234567"
          {:error, :timeout}
        end)

        # Faraday should NOT be called - use reject to ensure it's never called
        reject(&WaltUi.Enrichment.Faraday.fetch_by_identity_sets/1)

        # Mock TypeSense index - will be called once for LeadCreated event from await_contact
        stub(ExTypesense, :index_document, fn _index_data ->
          {:ok, %{}}
        end)

        # TypeSense update should NOT be called - use reject to ensure it's never called
        reject(&ExTypesense.update_document/1)

        contact =
          await_contact(
            avatar: nil,
            city: nil,
            email: nil,
            first_name: "John",
            last_name: "Doen",
            phone: "5551234567",
            ptt: nil,
            state: nil,
            street_1: nil,
            user_id: user.id,
            zip: nil
          )

        # Assert Trestle is requested
        assert_receive_event(
          CQRS,
          ProviderEnrichmentRequested,
          fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
          fn evt ->
            assert evt.contact_data.phone == "5551234567"
          end
        )

        # Assert Trestle failure is captured
        assert_receive_event(
          CQRS,
          ProviderEnrichmentCompleted,
          fn evt ->
            evt.id == enrichment_id && evt.provider_type == "trestle" && evt.status == "error"
          end,
          fn evt ->
            assert evt.error_data.reason == :timeout
            assert is_nil(evt.enrichment_data)
          end
        )

        # The pipeline should stop here - no Faraday request, no composition

        # Verify contact and enrichment projections remain unchanged
        assert_async do
          # Contact should remain in original state (no enrichment updates)
          updated_contact = Repo.get(Contact, contact.id)
          # No address updates
          assert updated_contact.street_1 == contact.street_1
          # No Move Score updates
          assert updated_contact.ptt == contact.ptt
        end

        # Verify no enrichment projection was created
        assert_async do
          enrichment = Repo.get(Enrichment, enrichment_id)
          # No enrichment record should exist
          assert is_nil(enrichment)
        end
      end)
    end

    test "Faraday failure still composes with Trestle data" do
      with_testing_mode(:inline, fn ->
        # Setup test data
        user = insert(:user)
        enrichment_id = UUID.uuid5(:oid, "5551234567")

        # Mock Trestle API to succeed with age range and contact data
        expect(WaltUi.Enrichment.Trestle.Http, :search_by_phone, fn phone, _opts ->
          assert phone == "5551234567"

          {:ok,
           %{
             "owners" => [
               %{
                 "firstname" => "John",
                 "lastname" => "Doe",
                 "age_range" => "25-34",
                 "phone" => "5551234567",
                 "emails" => ["john.doe@example.com"],
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

        # Mock Faraday API to fail
        expect(WaltUi.Enrichment.Faraday, :fetch_by_identity_sets, fn _id_sets ->
          {:error, :timeout}
        end)

        # Mock TypeSense index - will be called once for LeadCreated event from await_contact
        stub(ExTypesense, :index_document, fn _index_data ->
          {:ok, %{}}
        end)

        # Mock TypeSense update - should still happen with Trestle data
        expect(ExTypesense, :update_document, fn update_data ->
          assert update_data.collection_name == "contacts"
          assert update_data.city == "Austin"
          assert update_data.ptt == 0
          assert update_data.state == "TX"
          assert update_data.street_1 == "123 Main St"
          assert update_data.zip == "78701"
          assert update_data.updated_at

          {:ok, %{}}
        end)

        contact =
          await_contact(
            avatar: nil,
            city: nil,
            email: nil,
            first_name: "John",
            last_name: "Doen",
            phone: "5551234567",
            ptt: nil,
            state: nil,
            street_1: nil,
            user_id: user.id,
            zip: nil
          )

        # Assert Trestle is requested
        assert_receive_event(
          CQRS,
          ProviderEnrichmentRequested,
          fn evt -> evt.id == enrichment_id && evt.provider_type == "trestle" end,
          fn evt ->
            assert evt.contact_data.phone == "5551234567"
          end
        )

        # Assert Trestle success triggers Faraday request
        assert_receive_event(
          CQRS,
          ProviderEnrichmentCompleted,
          fn evt ->
            evt.id == enrichment_id && evt.provider_type == "trestle" && evt.status == "success"
          end,
          fn evt ->
            assert evt.enrichment_data
            assert evt.enrichment_data.first_name == "John"
            assert evt.enrichment_data.age_range == "25-34"
          end
        )

        # Assert Faraday is requested (but will fail)
        assert_receive_event(
          CQRS,
          ProviderEnrichmentRequested,
          fn evt -> evt.id == enrichment_id && evt.provider_type == "faraday" end,
          fn evt ->
            assert evt.contact_data.phone == "5551234567"
          end
        )

        # Assert Faraday failure
        assert_receive_event(
          CQRS,
          ProviderEnrichmentCompleted,
          fn evt ->
            evt.id == enrichment_id && evt.provider_type == "faraday" && evt.status == "error"
          end,
          fn evt ->
            assert evt.error_data.reason == :timeout
            assert is_nil(evt.enrichment_data)
          end
        )

        # Assert composition still happens with Trestle data only
        assert_receive_event(
          CQRS,
          EnrichmentComposed,
          fn evt ->
            evt.id == enrichment_id && Map.has_key?(evt.provider_scores, "trestle")
          end,
          fn evt ->
            # Verify composition contains Trestle data
            assert evt.composed_data.first_name == "John"
            assert evt.composed_data.last_name == "Doe"
            # Composer converts age_range to age
            assert evt.composed_data.age == "25-34"
            assert evt.phone == "5551234567"

            # Verify NO Faraday-specific data in composition
            refute Map.has_key?(evt.composed_data, "household_income")
            refute Map.has_key?(evt.composed_data, "ptt")

            # Verify data sources show only Trestle
            assert evt.data_sources.first_name == "trestle"
            assert evt.data_sources.last_name == "trestle"
            # Composer uses 'age' not 'age_range'
            assert evt.data_sources.age == "trestle"
            refute Map.has_key?(evt.data_sources, "household_income")

            # Verify provider scores show only Trestle
            assert evt.provider_scores["trestle"] > 0
            refute Map.has_key?(evt.provider_scores, "faraday")
          end
        )

        # Verify enrichment projection updated with Trestle data only
        assert_async do
          assert enrichment = Repo.get(Enrichment, enrichment_id)
          # Should contain Trestle age_range (formatted as is)
          assert enrichment.age == "25-34"
          # Should NOT contain Faraday data
          assert is_nil(enrichment.household_income)
          assert enrichment.full_name == "John Doe"
        end

        # Verify contact projection updated with Trestle data only
        assert_async do
          updated_contact = Repo.get(Contact, contact.id)
          assert updated_contact.enrichment_id == enrichment_id
          assert updated_contact.street_1 == "123 Main St"
          assert updated_contact.city == "Austin"
          assert updated_contact.state == "TX"
          assert updated_contact.zip == "78701"
          # No Move Score from Faraday
          assert updated_contact.ptt == 0
        end
      end)
    end
  end
end
