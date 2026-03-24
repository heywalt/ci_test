defmodule WaltUi.Projectors.FaradayTest do
  use WaltUi.CqrsCase

  import AssertAsync
  import WaltUi.Factory

  alias CQRS.Enrichments.Events.EnrichedWithFaraday
  alias CQRS.Enrichments.Events.EnrichmentReset
  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias WaltUi.Projections.Faraday

  describe "EnrichedWithFaraday event" do
    test "projects new faraday data" do
      event_id = Ecto.UUID.generate()

      :faraday
      |> params_for(id: event_id)
      |> Map.put(:timestamp, NaiveDateTime.utc_now())
      |> then(&struct(EnrichedWithFaraday, &1))
      |> append_event()

      assert_async do
        assert [%{id: ^event_id}] = Repo.all(Faraday)
      end
    end

    test "updates existing faraday data" do
      record = insert(:faraday, garage_spaces: 1)

      :faraday
      |> params_for(id: record.id, garage_spaces: 3)
      |> Map.put(:timestamp, NaiveDateTime.utc_now())
      |> then(&struct(EnrichedWithFaraday, &1))
      |> append_event()

      assert_async do
        assert [%{garage_spaces: 3}] = Repo.all(Faraday)
      end
    end
  end

  describe "ProviderEnrichmentCompleted event with faraday provider" do
    test "projects new faraday data from successful enrichment" do
      event_id = Ecto.UUID.generate()
      faraday_data = params_for(:faraday, id: event_id)

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: faraday_data,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{id: ^event_id}] = Repo.all(Faraday)
      end
    end

    test "updates existing faraday data from successful enrichment" do
      record = insert(:faraday, garage_spaces: 1)

      faraday_data = params_for(:faraday, id: record.id, garage_spaces: 3)

      event = %ProviderEnrichmentCompleted{
        id: record.id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: faraday_data,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [%{garage_spaces: 3}] = Repo.all(Faraday)
      end
    end

    test "ignores non-faraday provider events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "trestle",
        status: "success",
        enrichment_data: %{first_name: "John"},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(Faraday)
      end
    end

    test "ignores error status enrichment events" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "error",
        error_data: %{reason: "timeout"},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(Faraday)
      end
    end

    test "handles homeowner_status as atom in enrichment_data" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          first_name: "John",
          # Unexpected type - should be set to nil
          homeowner_status: :owner
        },
        quality_metadata: %{match_type: "address_only"},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert %{id: ^event_id, homeowner_status: nil} = Repo.get(Faraday, event_id)
      end
    end

    test "handles homeowner_status as integer in enrichment_data (like 0)" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          first_name: "Jane",
          # This is the real production issue
          homeowner_status: 0
        },
        quality_metadata: %{match_type: "phone_only"},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert %{id: ^event_id, homeowner_status: nil} = Repo.get(Faraday, event_id)
      end
    end

    test "handles homeowner_status as boolean in enrichment_data" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          first_name: "Bob",
          # Unexpected type - should be set to nil
          homeowner_status: true
        },
        quality_metadata: %{match_type: "full_match"},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert %{id: ^event_id, homeowner_status: nil} = Repo.get(Faraday, event_id)
      end
    end

    test "handles homeowner_status as valid string in enrichment_data" do
      event_id = Ecto.UUID.generate()

      event = %ProviderEnrichmentCompleted{
        id: event_id,
        phone: "5551234567",
        provider_type: "faraday",
        status: "success",
        enrichment_data: %{
          first_name: "Alice",
          # This should work fine
          homeowner_status: "Probable Owner"
        },
        quality_metadata: %{match_type: "full_match"},
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert %{id: ^event_id, homeowner_status: "Probable Owner"} = Repo.get(Faraday, event_id)
      end
    end
  end

  describe "EnrichmentReset event" do
    test "deletes faraday record for existing enrichment" do
      faraday = insert(:faraday, first_name: "John", last_name: "Doe")

      event = %EnrichmentReset{
        id: faraday.id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(Faraday)
      end
    end

    test "handles reset for non-existent enrichment_id" do
      # Create a faraday record to ensure database isn't empty
      existing_faraday = insert(:faraday, first_name: "Jane")
      non_existent_id = Ecto.UUID.generate()

      event = %EnrichmentReset{
        id: non_existent_id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        # Existing faraday should remain unchanged
        faradays = Repo.all(Faraday)
        assert [%{id: id}] = faradays
        assert id == existing_faraday.id
      end
    end
  end
end
