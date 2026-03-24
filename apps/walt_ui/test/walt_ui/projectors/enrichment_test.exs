defmodule WaltUi.Projectors.EnrichmentTest do
  use WaltUi.CqrsCase

  import AssertAsync
  import WaltUi.Factory

  alias CQRS.Enrichments.Events.EnrichedWithFaraday
  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Enrichments.Events.EnrichmentReset
  alias WaltUi.Projections.Enrichment

  describe "EnrichedWithFaraday event" do
    test "projects new faraday data into enrichments" do
      event_id = Ecto.UUID.generate()

      :faraday
      |> params_for(id: event_id)
      |> Map.put(:timestamp, NaiveDateTime.utc_now())
      |> then(&struct(EnrichedWithFaraday, &1))
      |> append_event()

      assert_async do
        assert [%{id: ^event_id}] = Repo.all(Enrichment)
      end
    end

    test "updates existing enrichment data" do
      record = insert(:faraday, occupation: "Software Engineer")

      :faraday
      |> params_for(id: record.id, occupation: "Engineering Manager")
      |> Map.put(:timestamp, NaiveDateTime.utc_now())
      |> then(&struct(EnrichedWithFaraday, &1))
      |> append_event()

      assert_async do
        assert [%{occupation: "Engineering Manager"}] = Repo.all(Enrichment)
      end
    end
  end

  describe "EnrichmentComposed event" do
    test "projects new composed enrichment data into enrichments" do
      event_id = Ecto.UUID.generate()

      # Create composed_data with same structure as Faraday data
      composed_data = %{
        first_name: "John",
        last_name: "Smith",
        age: 35,
        education: "Bachelor's Degree",
        household_income: 75_000,
        occupation: "Software Engineer",
        property_type: "Single Family",
        number_of_bedrooms: 3,
        has_pet: true
      }

      event = %EnrichmentComposed{
        id: event_id,
        phone: "5551234567",
        composed_data: composed_data,
        data_sources: %{age: :faraday, first_name: :trestle},
        provider_scores: %{faraday: 85, trestle: 90},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        enrichments = Repo.all(Enrichment)
        assert [%{id: ^event_id} = enrichment] = enrichments
        assert enrichment.first_name == "John"
        assert enrichment.last_name == "Smith"
        assert enrichment.full_name == "John Smith"
        assert enrichment.age == "35-44"
        assert enrichment.education == "Bachelor's Degree"
        assert enrichment.household_income == "$70k+"
        assert enrichment.occupation == "Software Engineer"
        assert enrichment.property_type == "Single Family"
        assert enrichment.number_of_bedrooms == "3-4"
        assert enrichment.has_pet == true
      end
    end

    test "updates existing enrichment data from composed data" do
      # Insert existing enrichment record
      existing_enrichment = insert(:enrichment, occupation: "Manager")

      composed_data = %{
        first_name: "Jane",
        last_name: "Doe",
        age: 42,
        occupation: "Senior Manager",
        household_income: 95_000
      }

      event = %EnrichmentComposed{
        id: existing_enrichment.id,
        phone: "5551234567",
        composed_data: composed_data,
        data_sources: %{age: :faraday, first_name: :trestle},
        provider_scores: %{faraday: 80, trestle: 85},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        enrichments = Repo.all(Enrichment)
        assert [%{occupation: "Senior Manager"} = enrichment] = enrichments
        assert enrichment.first_name == "Jane"
        assert enrichment.last_name == "Doe"
        assert enrichment.full_name == "Jane Doe"
        assert enrichment.age == "35-44"
        assert enrichment.household_income == "$90k+"
      end
    end

    test "handles composed data with nil fields gracefully" do
      event_id = Ecto.UUID.generate()

      composed_data = %{
        first_name: "Alice",
        last_name: "Johnson",
        age: nil,
        education: nil,
        household_income: 50_000,
        occupation: "Teacher"
      }

      event = %EnrichmentComposed{
        id: event_id,
        phone: "5551234567",
        composed_data: composed_data,
        data_sources: %{first_name: :trestle, household_income: :faraday},
        provider_scores: %{faraday: 75, trestle: 80},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        enrichments = Repo.all(Enrichment)
        assert [%{id: ^event_id} = enrichment] = enrichments
        assert enrichment.first_name == "Alice"
        assert enrichment.last_name == "Johnson"
        assert enrichment.full_name == "Alice Johnson"
        assert enrichment.age == nil
        assert enrichment.education == nil
        assert enrichment.household_income == "$50k+"
        assert enrichment.occupation == "Teacher"
      end
    end

    test "applies transformation logic to composed data fields" do
      event_id = Ecto.UUID.generate()

      composed_data = %{
        age: 28,
        household_income: 125_000,
        latest_mortgage_amount: 350_000,
        net_worth: 75_000,
        number_of_bedrooms: 2,
        number_of_bathrooms: 1,
        latest_mortgage_interest_rate: 4.25,
        percent_equity: 15,
        lot_size_in_acres: 0.75
      }

      event = %EnrichmentComposed{
        id: event_id,
        phone: "5551234567",
        composed_data: composed_data,
        data_sources: %{},
        provider_scores: %{faraday: 85},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        enrichments = Repo.all(Enrichment)
        assert [%{id: ^event_id} = enrichment] = enrichments

        # Test transformation functions are applied
        assert enrichment.age == "25-34"
        assert enrichment.household_income == "$120k+"
        assert enrichment.latest_mortgage_amount == "$300k-$350k"
        assert enrichment.net_worth == "$50k-$100k"
        assert enrichment.number_of_bedrooms == "0-2"
        assert enrichment.number_of_bathrooms == "0-2"
        assert enrichment.latest_mortgage_interest_rate == "4-5%"
        assert enrichment.percent_equity == "10%-20%"
        assert enrichment.lot_size_in_acres == "0.5-1"
      end
    end

    test "handles Trestle age range strings correctly" do
      event_id = Ecto.UUID.generate()

      composed_data = %{
        first_name: "Sarah",
        last_name: "Wilson",
        # Trestle returns age ranges as strings
        age: "31-35",
        occupation: "Teacher"
      }

      event = %EnrichmentComposed{
        id: event_id,
        phone: "5551234567",
        composed_data: composed_data,
        data_sources: %{age: :trestle, first_name: :trestle},
        provider_scores: %{trestle: 85},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        enrichments = Repo.all(Enrichment)
        assert [%{id: ^event_id} = enrichment] = enrichments
        assert enrichment.first_name == "Sarah"
        assert enrichment.last_name == "Wilson"
        assert enrichment.full_name == "Sarah Wilson"
        # Should pass through Trestle age range as-is
        assert enrichment.age == "31-35"
        assert enrichment.occupation == "Teacher"
      end
    end

    test "handles float values for probability_to_have_hot_tub" do
      event_id = Ecto.UUID.generate()

      composed_data = %{
        probability_to_have_hot_tub: 39.5
      }

      event = %EnrichmentComposed{
        id: event_id,
        phone: "5551234567",
        timestamp: NaiveDateTime.utc_now(),
        composed_data: composed_data,
        data_sources: %{probability_to_have_hot_tub: "faraday"},
        provider_scores: %{faraday: 20}
      }

      append_event(event)

      assert_async do
        enrichment = Repo.get(Enrichment, event_id)
        assert enrichment != nil
        assert enrichment.probability_to_have_hot_tub == "30%-40%"
      end
    end

    test "handles float values for living_area" do
      event_id = Ecto.UUID.generate()

      composed_data = %{
        living_area: 247.5
      }

      event = %EnrichmentComposed{
        id: event_id,
        phone: "5551234567",
        timestamp: NaiveDateTime.utc_now(),
        composed_data: composed_data,
        data_sources: %{living_area: "faraday"},
        provider_scores: %{faraday: 85}
      }

      append_event(event)

      assert_async do
        enrichment = Repo.get(Enrichment, event_id)
        assert enrichment != nil
        # 247.5 truncated to 247, then * 10.76391 = 2658.68577, rounded = 2659
        assert enrichment.living_area == "2659"
      end
    end

    test "handles various numeric types for area fields" do
      event_id = Ecto.UUID.generate()

      composed_data = %{
        living_area: 288.0,
        basement_area: "150",
        lot_area: 500
      }

      event = %EnrichmentComposed{
        id: event_id,
        phone: "5551234567",
        timestamp: NaiveDateTime.utc_now(),
        composed_data: composed_data,
        data_sources: %{
          living_area: "faraday",
          basement_area: "faraday",
          lot_area: "faraday"
        },
        provider_scores: %{faraday: 90}
      }

      append_event(event)

      assert_async do
        enrichment = Repo.get(Enrichment, event_id)
        assert enrichment != nil
        # 288.0 truncated to 288, then * 10.76391 = 3100.00608, rounded = 3100
        assert enrichment.living_area == "3100"
        # 150 (string) -> 150 * 10.76391 = 1614.5865, rounded = 1615
        assert enrichment.basement_area == "1615"
        # 500 / 4047 = 0.12355, rounded to 2 decimal places = 0.12
        assert enrichment.lot_area == "0.12"
      end
    end
  end

  describe "EnrichmentReset event" do
    test "deletes enrichment record for existing enrichment" do
      enrichment = insert(:enrichment, first_name: "John", last_name: "Doe")

      event = %EnrichmentReset{
        id: enrichment.id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(Enrichment)
      end
    end

    test "handles reset for non-existent enrichment_id" do
      # Create an enrichment to ensure database isn't empty
      existing_enrichment = insert(:enrichment, first_name: "Jane")
      non_existent_id = Ecto.UUID.generate()

      event = %EnrichmentReset{
        id: non_existent_id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        # Existing enrichment should remain unchanged
        enrichments = Repo.all(Enrichment)
        assert [%{id: id}] = enrichments
        assert id == existing_enrichment.id
      end
    end
  end
end
