defmodule WaltUi.Handlers.EnrichmentCompositionRequestedHandlerTest do
  use WaltUi.CqrsCase

  alias CQRS.Enrichments.Data.ProviderData
  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Enrichments.Events.EnrichmentCompositionRequested
  alias WaltUi.Handlers.EnrichmentCompositionRequestedHandler

  describe "handle/2 with successful single provider" do
    test "dispatches CompleteEnrichmentComposition command with correct data" do
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            first_name: "John",
            last_name: "Smith",
            age_range: "35-44"
          },
          quality_metadata: %{match_count: 1, name_hint: "John Smith"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      event = %EnrichmentCompositionRequested{
        id: Ecto.UUID.generate(),
        provider_data: provider_data,
        composition_rules: :default,
        timestamp: NaiveDateTime.utc_now()
      }

      assert :ok = EnrichmentCompositionRequestedHandler.handle(event, %{})

      assert_receive_event(CQRS, EnrichmentComposed, fn evt ->
        assert evt.id == event.id
        assert evt.composed_data.first_name == "John"
        assert evt.composed_data.last_name == "Smith"
        assert evt.composed_data.age == "35-44"
        assert evt.data_sources.first_name == "trestle"
        assert evt.data_sources.last_name == "trestle"
        assert evt.data_sources.age == "trestle"
        assert is_map(evt.provider_scores)
        assert Map.has_key?(evt.provider_scores, "trestle")
        assert is_integer(evt.provider_scores["trestle"])
        # Phone should be included from aggregate state
        # Note: Phone will be nil in this isolated test since we're not setting up the aggregate state
        # This is tested in the full integration flow
      end)
    end
  end

  describe "handle/2 with successful multiple providers" do
    test "uses quality-based composition for field selection" do
      provider_data = [
        %ProviderData{
          provider_type: "trestle",
          status: "success",
          enrichment_data: %{
            first_name: "John",
            last_name: "Smith",
            age_range: "35-44",
            addresses: [%{city: "Columbus", state: "OH", street_1: "123 Main St", zip: "43215"}],
            emails: ["john@example.com"]
          },
          quality_metadata: %{match_count: 1, name_hint: "John Smith"},
          received_at: NaiveDateTime.utc_now()
        },
        %ProviderData{
          provider_type: "faraday",
          status: "success",
          enrichment_data: %{
            age: 35,
            city: "Chicago",
            state: "IL",
            household_income: 95_000,
            education: "Bachelor's Degree",
            has_pet: true
          },
          quality_metadata: %{match_type: "address_full_name"},
          received_at: NaiveDateTime.utc_now()
        }
      ]

      event = %EnrichmentCompositionRequested{
        id: Ecto.UUID.generate(),
        provider_data: provider_data,
        composition_rules: :default,
        timestamp: NaiveDateTime.utc_now()
      }

      assert :ok = EnrichmentCompositionRequestedHandler.handle(event, %{})

      assert_receive_event(CQRS, EnrichmentComposed, fn evt ->
        assert evt.id == event.id

        # Trestle should win for contact info (higher quality score: 95 vs 90)
        assert evt.composed_data.first_name == "John"
        assert evt.composed_data.last_name == "Smith"
        # Trestle age_range wins over Faraday age
        assert evt.composed_data.age == "35-44"
        assert evt.composed_data.email == "john@example.com"

        # Faraday should win for address (demographic data is based on Faraday's matched address)
        assert evt.composed_data.city == "Chicago"
        assert evt.composed_data.state == "IL"

        # Faraday should win for demographic data (field capabilities)
        assert evt.composed_data.household_income == 95_000
        assert evt.composed_data.education == "Bachelor's Degree"
        assert evt.composed_data.has_pet == true

        # Verify data sources show correct provider selection
        assert evt.data_sources.first_name == "trestle"
        assert evt.data_sources.last_name == "trestle"
        assert evt.data_sources.age == "trestle"
        assert evt.data_sources.email == "trestle"

        # Address fields should be from Faraday
        assert evt.data_sources.city == "faraday"
        assert evt.data_sources.state == "faraday"

        # Demographic data from Faraday (field capabilities)
        assert evt.data_sources.household_income == "faraday"
        assert evt.data_sources.education == "faraday"
        assert evt.data_sources.has_pet == "faraday"
      end)
    end
  end

  describe "handle/2 with no successful providers" do
    test "handles empty provider_data gracefully" do
      event = %EnrichmentCompositionRequested{
        id: Ecto.UUID.generate(),
        provider_data: [],
        composition_rules: :default,
        timestamp: NaiveDateTime.utc_now()
      }

      # Should not emit any EnrichmentComposed event
      refute_receive_event(CQRS, EnrichmentComposed, fn ->
        assert :ok = EnrichmentCompositionRequestedHandler.handle(event, %{})
      end)
    end
  end
end
