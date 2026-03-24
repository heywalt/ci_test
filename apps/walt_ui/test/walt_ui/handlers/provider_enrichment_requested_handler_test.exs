defmodule WaltUi.Handlers.ProviderEnrichmentRequestedHandlerTest do
  use Repo.DataCase, async: false
  use Oban.Testing, repo: Repo

  alias CQRS.Enrichments.Events.ProviderEnrichmentRequested
  alias WaltUi.Enrichment.FaradayJob
  alias WaltUi.Enrichment.TrestleJob
  alias WaltUi.Handlers.ProviderEnrichmentRequestedHandler

  describe "handle/2" do
    test "enqueues TrestleJob for trestle provider type" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user_id = Ecto.UUID.generate()

        event = %ProviderEnrichmentRequested{
          id: Ecto.UUID.generate(),
          provider_type: "trestle",
          contact_data: %{
            last_name: "Doe",
            user_id: user_id,
            emails: ["john@example.com"],
            addresses: []
          },
          provider_config: %{},
          timestamp: NaiveDateTime.utc_now()
        }

        metadata = %{
          event_id: Ecto.UUID.generate(),
          correlation_id: Ecto.UUID.generate()
        }

        assert :ok = ProviderEnrichmentRequestedHandler.handle(event, metadata)

        expected_event = Map.from_struct(event)

        assert_enqueued(
          worker: TrestleJob,
          args: %{"event" => expected_event, "user_id" => user_id}
        )
      end)
    end

    test "enqueues FaradayJob for faraday provider type" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user_id = Ecto.UUID.generate()

        event = %ProviderEnrichmentRequested{
          id: Ecto.UUID.generate(),
          provider_type: "faraday",
          contact_data: %{
            last_name: "Smith",
            user_id: user_id,
            emails: ["jane@example.com"],
            addresses: []
          },
          provider_config: %{},
          timestamp: NaiveDateTime.utc_now()
        }

        metadata = %{
          event_id: Ecto.UUID.generate(),
          correlation_id: Ecto.UUID.generate()
        }

        assert :ok = ProviderEnrichmentRequestedHandler.handle(event, metadata)

        expected_event = Map.from_struct(event)

        assert_enqueued(
          worker: FaradayJob,
          args: %{"event" => expected_event, "user_id" => user_id}
        )
      end)
    end

    test "returns error for unknown provider type" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        event = %ProviderEnrichmentRequested{
          id: Ecto.UUID.generate(),
          provider_type: "test_provider",
          contact_data: %{
            last_name: "User"
          },
          provider_config: %{},
          timestamp: NaiveDateTime.utc_now()
        }

        metadata = %{
          event_id: Ecto.UUID.generate(),
          correlation_id: Ecto.UUID.generate()
        }

        assert {:error, {:unknown_provider, "test_provider"}} =
                 ProviderEnrichmentRequestedHandler.handle(event, metadata)

        refute_enqueued(worker: TrestleJob)
        refute_enqueued(worker: FaradayJob)
      end)
    end
  end
end
