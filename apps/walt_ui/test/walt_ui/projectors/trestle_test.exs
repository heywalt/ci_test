defmodule WaltUi.Projectors.TrestleTest do
  use WaltUi.CqrsCase

  import AssertAsync
  import WaltUi.Factory

  alias CQRS.Enrichments.Events
  alias CQRS.Enrichments.Events.EnrichmentReset
  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted

  describe "EnrichedWithTrestle event" do
    test "projects new trestle data" do
      append_event(%Events.EnrichedWithTrestle{
        id: Ecto.UUID.generate(),
        addresses: [
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          }
        ],
        age_range: "35-44",
        emails: ["foo@bar.com"],
        first_name: "Foo",
        last_name: "Bar",
        phone: "5551231234",
        timestamp: NaiveDateTime.utc_now()
      })

      assert_async do
        assert [
                 %{
                   age_range: "35-44",
                   emails: ["foo@bar.com"],
                   first_name: "Foo",
                   last_name: "Bar",
                   phone: "5551231234",
                   addresses: [
                     %{
                       street_1: "123 Main St",
                       street_2: "Unit 3",
                       city: "Fooville",
                       state: "OH",
                       zip: "46862"
                     }
                   ]
                 }
               ] = Repo.all(WaltUi.Projections.Trestle)
      end
    end

    test "updates existing trestle data" do
      record = insert(:trestle)

      append_event(%Events.EnrichedWithTrestle{
        id: record.id,
        addresses: [
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          }
        ],
        age_range: "45-54",
        emails: ["foo@bar.com", "test@test.org"],
        first_name: "Wade",
        last_name: "Wilson",
        phone: "5551231234",
        timestamp: NaiveDateTime.utc_now()
      })

      assert_async do
        assert [
                 %{
                   age_range: "45-54",
                   emails: ["foo@bar.com", "test@test.org"],
                   first_name: "Wade",
                   last_name: "Wilson",
                   phone: "5551231234",
                   addresses: [
                     %{
                       street_1: "123 Main St",
                       street_2: "Unit 3",
                       city: "Fooville",
                       state: "OH",
                       zip: "46862"
                     }
                   ]
                 }
               ] = Repo.all(WaltUi.Projections.Trestle)
      end
    end
  end

  describe "ProviderEnrichmentCompleted event with trestle provider" do
    test "projects new trestle data from successful enrichment" do
      event_id = Ecto.UUID.generate()

      trestle_data = %{
        addresses: [
          %{
            street_1: "123 Main St",
            street_2: "Unit 3",
            city: "Fooville",
            state: "OH",
            zip: "46862"
          }
        ],
        age_range: "35-44",
        emails: ["foo@bar.com"],
        first_name: "John",
        last_name: "Doe",
        phone: "5551231234"
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        status: "success",
        enrichment_data: trestle_data,
        phone: "5551231234",
        provider_type: "trestle",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{id: ^event_id, first_name: "John", age_range: "35-44"}] =
                 Repo.all(WaltUi.Projections.Trestle)
      end
    end

    test "updates existing trestle data from successful enrichment" do
      event_id = Ecto.UUID.generate()
      _record = insert(:trestle, id: event_id, age_range: "25-34")

      trestle_data = %{
        addresses: [
          %{
            street_1: "456 New St",
            street_2: nil,
            city: "Newville",
            state: "CA",
            zip: "90210"
          }
        ],
        age_range: "45-54",
        emails: ["new@example.com"],
        first_name: "New",
        last_name: "Name",
        phone: "5559876543"
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        status: "success",
        enrichment_data: trestle_data,
        phone: "5559876543",
        provider_type: "trestle",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{first_name: "New", age_range: "45-54"}] = Repo.all(WaltUi.Projections.Trestle)
      end
    end

    test "ignores non-trestle provider events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        status: "success",
        enrichment_data: %{age: 35},
        phone: "5551231234",
        provider_type: "other",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(WaltUi.Projections.Trestle)
      end
    end

    test "ignores error status enrichment events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        status: "error",
        error_data: %{reason: "timeout"},
        phone: "5551231234",
        provider_type: "trestle",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(WaltUi.Projections.Trestle)
      end
    end

    test "projects alternate names from enrichment data" do
      event_id = Ecto.UUID.generate()

      trestle_data = %{
        first_name: "William",
        last_name: "Smith",
        phone: "5551231234",
        alternate_names: ["Bill Smith", "Will Smith", "Billy Smith"]
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        status: "success",
        enrichment_data: trestle_data,
        phone: "5551231234",
        provider_type: "trestle",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{alternate_names: ["Bill Smith", "Will Smith", "Billy Smith"]}] =
                 Repo.all(WaltUi.Projections.Trestle)
      end
    end

    test "handles missing alternate names in enrichment data" do
      event_id = Ecto.UUID.generate()

      trestle_data = %{
        first_name: "John",
        last_name: "Doe",
        phone: "5551231234"
        # alternate_names not present
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        status: "success",
        enrichment_data: trestle_data,
        phone: "5551231234",
        provider_type: "trestle",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{alternate_names: []}] = Repo.all(WaltUi.Projections.Trestle)
      end
    end

    test "handles empty alternate names array" do
      event_id = Ecto.UUID.generate()

      trestle_data = %{
        first_name: "Jane",
        last_name: "Doe",
        phone: "5551231234",
        alternate_names: []
      }

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        status: "success",
        enrichment_data: trestle_data,
        phone: "5551231234",
        provider_type: "trestle",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{alternate_names: []}] = Repo.all(WaltUi.Projections.Trestle)
      end
    end
  end

  describe "EnrichmentReset event" do
    test "deletes trestle record for existing enrichment" do
      trestle = insert(:trestle, first_name: "John", last_name: "Doe")

      event = %EnrichmentReset{
        id: trestle.id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(WaltUi.Projections.Trestle)
      end
    end

    test "handles reset for non-existent enrichment_id" do
      # Create a trestle record to ensure database isn't empty
      existing_trestle = insert(:trestle, first_name: "Jane")
      non_existent_id = Ecto.UUID.generate()

      event = %EnrichmentReset{
        id: non_existent_id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        # Existing trestle should remain unchanged
        trestles = Repo.all(WaltUi.Projections.Trestle)
        assert [%{id: id}] = trestles
        assert id == existing_trestle.id
      end
    end
  end
end
