defmodule WaltUi.Enrichment.FaradayJobTest do
  use Repo.DataCase
  use Mimic

  import Commanded.Assertions.EventAssertions

  alias CQRS.Enrichments.Events.ProviderEnrichmentCompleted
  alias WaltUi.Enrichment.Faraday
  alias WaltUi.Enrichment.FaradayJob

  setup :verify_on_exit!

  describe "perform/1" do
    test "dispatches CompleteProviderEnrichment command on successful enrichment" do
      # Mock the Faraday API call
      expect(Faraday, :fetch_by_identity_sets, fn _id_sets ->
        {:ok,
         %{
           "match_type" => "address_full_name",
           "fdy_attribute_fig_age" => 30,
           "person_first_name" => "John",
           "person_last_name" => "Doe",
           "fdy_attribute_fig_household_income" => 75_000
         }}
      end)

      event = %{
        "id" => Ecto.UUID.generate(),
        "provider_type" => "faraday",
        "contact_data" => %{
          "phone" => "1234567890",
          "first_name" => "John",
          "last_name" => "Doe",
          "emails" => ["john@example.com"],
          "addresses" => [
            %{
              "street_1" => "123 Main St",
              "street_2" => "",
              "city" => "Austin",
              "state" => "TX",
              "zip" => "78701"
            }
          ]
        },
        "provider_config" => %{},
        "timestamp" => NaiveDateTime.utc_now()
      }

      job = %Oban.Job{args: %{"event" => event}}

      assert :ok = FaradayJob.perform(job)

      # Assert that a ProviderEnrichmentCompleted event was dispatched
      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == event["id"] && evt.provider_type == "faraday" end,
        fn evt ->
          assert evt.status == "success"
          assert evt.enrichment_data.age == 30
          assert evt.enrichment_data.first_name == "John"
          assert evt.enrichment_data.last_name == "Doe"
          assert evt.enrichment_data.household_income == 75_000
          assert evt.quality_metadata.match_type == "address_full_name"
        end
      )
    end

    test "dispatches CompleteProviderEnrichment with cancellation status on API failure" do
      # Mock the Faraday API call to fail
      expect(Faraday, :fetch_by_identity_sets, fn _id_sets ->
        {:error, :timeout}
      end)

      event = %{
        "id" => Ecto.UUID.generate(),
        "provider_type" => "faraday",
        "contact_data" => %{
          "phone" => "1234567890",
          "first_name" => "John",
          "last_name" => "Doe",
          "emails" => ["john@example.com"],
          "addresses" => [
            %{
              "street_1" => "123 Main St",
              "street_2" => "",
              "city" => "Austin",
              "state" => "TX",
              "zip" => "78701"
            }
          ]
        },
        "provider_config" => %{},
        "timestamp" => NaiveDateTime.utc_now()
      }

      job = %Oban.Job{args: %{"event" => event}}

      assert {:cancel, :unknown_error} = FaradayJob.perform(job)

      # Verify the error event was dispatched
      assert_receive_event(
        CQRS,
        ProviderEnrichmentCompleted,
        fn evt -> evt.id == event["id"] && evt.provider_type == "faraday" end,
        fn evt ->
          assert evt.status == "error"
          assert evt.enrichment_data == nil
          assert evt.error_data.reason == :timeout
        end
      )
    end
  end
end
