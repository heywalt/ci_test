defmodule WaltUi.Enrichment.UnificationJobTest do
  use WaltUi.CqrsCase
  use Oban.Testing, repo: Repo
  use Mimic

  alias CQRS.Leads.Events.LeadUnified
  alias WaltUi.Enrichment.OpenAi
  alias WaltUi.Enrichment.UnificationJob

  setup [:set_mimic_from_context, :verify_on_exit!]

  describe "process/1 - successful identity match" do
    test "dispatches Unify command when OpenAI confirms identity match" do
      # Arrange - create actual lead aggregate
      contact = await_contact()
      enrichment_id = Ecto.UUID.generate()

      args = %{
        contact_id: contact.id,
        contact_first_name: "John",
        contact_last_name: "Doe",
        enrichment_id: enrichment_id,
        enrichment_first_name: "John",
        enrichment_last_name: "Doe",
        enrichment_data: %{
          "ptt" => 85,
          "city" => "Austin",
          "state" => "TX",
          "street_1" => "123 Main St",
          "street_2" => "Apt 4B",
          "zip" => "78701"
        },
        enrichment_type: "best",
        user_id: contact.user_id
      }

      # Mock OpenAI to return successful match
      expect(OpenAi, :confirm_identity, fn contact_name, enrichment_name ->
        assert contact_name == %{first_name: "john", last_name: "doe"}
        assert enrichment_name == %{first_name: "john", last_name: "doe", alternate_names: []}
        {:ok, true}
      end)

      # Act
      assert :ok = perform_job(UnificationJob, args)

      # Assert - the lead aggregate should emit LeadUnified event
      assert_receive_event(
        CQRS,
        LeadUnified,
        fn evt -> evt.id == contact.id && evt.enrichment_id == enrichment_id end,
        fn evt ->
          assert evt.enrichment_type == :best
          assert evt.ptt == 85
          assert evt.city == "Austin"
          assert evt.state == "TX"
          assert evt.street_1 == "123 Main St"
          assert evt.street_2 == "Apt 4B"
          assert evt.zip == "78701"
        end
      )
    end

    test "uses default enrichment_type of 'lesser' when not provided" do
      # Arrange - create actual lead aggregate
      contact = await_contact()
      enrichment_id = Ecto.UUID.generate()

      args = %{
        contact_id: contact.id,
        contact_first_name: "Jane",
        contact_last_name: "Smith",
        enrichment_id: enrichment_id,
        enrichment_first_name: "Jane",
        enrichment_last_name: "Smith",
        enrichment_data: %{"ptt" => 50},
        enrichment_type: nil,
        user_id: contact.user_id
      }

      expect(OpenAi, :confirm_identity, fn _, _ ->
        {:ok, true}
      end)

      # Act
      assert :ok = perform_job(UnificationJob, args)

      # Assert
      assert_receive_event(
        CQRS,
        LeadUnified,
        fn evt -> evt.id == contact.id end,
        fn evt ->
          assert evt.enrichment_type == :lesser
        end
      )
    end

    test "handles missing optional fields in enrichment_data" do
      # Arrange - create actual lead aggregate
      contact = await_contact()
      enrichment_id = Ecto.UUID.generate()

      args = %{
        contact_id: contact.id,
        contact_first_name: "Bob",
        contact_last_name: "Johnson",
        enrichment_id: enrichment_id,
        enrichment_first_name: "Bob",
        enrichment_last_name: "Johnson",
        # Empty enrichment data
        enrichment_data: %{},
        enrichment_type: "lesser",
        user_id: contact.user_id
      }

      expect(OpenAi, :confirm_identity, fn _, _ ->
        {:ok, true}
      end)

      # Act
      assert :ok = perform_job(UnificationJob, args)

      # Assert
      assert_receive_event(
        CQRS,
        LeadUnified,
        fn evt -> evt.id == contact.id end,
        fn evt ->
          # Default value
          assert evt.ptt == 0
          assert is_nil(evt.city)
          assert is_nil(evt.state)
          assert is_nil(evt.street_1)
          assert is_nil(evt.street_2)
          assert is_nil(evt.zip)
        end
      )
    end
  end

  describe "process/1 - no identity match" do
    test "completes successfully when OpenAI does not confirm identity match" do
      # Arrange - create actual lead aggregate
      contact = await_contact()
      enrichment_id = Ecto.UUID.generate()

      args = %{
        contact_id: contact.id,
        contact_first_name: "John",
        contact_last_name: "Doe",
        enrichment_id: enrichment_id,
        # Different name
        enrichment_first_name: "Jane",
        # Different name
        enrichment_last_name: "Smith",
        enrichment_data: %{
          "ptt" => 85,
          "city" => "Austin",
          "state" => "TX"
        },
        enrichment_type: "best",
        user_id: contact.user_id
      }

      # Mock OpenAI to return no match
      expect(OpenAi, :confirm_identity, fn contact_name, enrichment_name ->
        assert contact_name == %{first_name: "john", last_name: "doe"}
        assert enrichment_name == %{first_name: "jane", last_name: "smith", alternate_names: []}
        {:ok, false}
      end)

      # Assert - no LeadUnified events should be emitted when job runs
      refute_receive_event(CQRS, LeadUnified, fn ->
        # Act - perform the job inside the refute_receive_event lambda
        assert :ok = perform_job(UnificationJob, args)
      end)
    end
  end

  describe "process/1 - OpenAI timeout handling" do
    test "returns error tuple when OpenAI times out" do
      # Arrange - create actual lead aggregate
      contact = await_contact()
      enrichment_id = Ecto.UUID.generate()

      args = %{
        contact_id: contact.id,
        contact_first_name: "John",
        contact_last_name: "Doe",
        enrichment_id: enrichment_id,
        enrichment_first_name: "John",
        enrichment_last_name: "Doe",
        enrichment_data: %{
          "ptt" => 85,
          "city" => "Austin",
          "state" => "TX"
        },
        enrichment_type: "best",
        user_id: contact.user_id
      }

      # Mock OpenAI to return timeout error
      expect(OpenAi, :confirm_identity, fn contact_name, enrichment_name ->
        assert contact_name == %{first_name: "john", last_name: "doe"}
        assert enrichment_name == %{first_name: "john", last_name: "doe", alternate_names: []}
        {:error, %{message: "OpenAI request timeout"}}
      end)

      # Assert - no LeadUnified events should be emitted and job should return error
      refute_receive_event(CQRS, LeadUnified, fn ->
        # Act & Assert - job should return error tuple for Oban retry
        assert {:error, "OpenAI timeout"} = perform_job(UnificationJob, args)
      end)
    end
  end

  describe "process/1 - other error handling" do
    test "completes successfully when OpenAI returns generic error" do
      # Arrange - create actual lead aggregate
      contact = await_contact()
      enrichment_id = Ecto.UUID.generate()

      args = %{
        contact_id: contact.id,
        contact_first_name: "Jane",
        contact_last_name: "Smith",
        enrichment_id: enrichment_id,
        enrichment_first_name: "Jane",
        enrichment_last_name: "Smith",
        enrichment_data: %{"ptt" => 50},
        enrichment_type: "lesser",
        user_id: contact.user_id
      }

      # Mock OpenAI to return a different error format
      expect(OpenAi, :confirm_identity, fn _, _ ->
        {:error, "Network connection failed"}
      end)

      # Assert - no LeadUnified events should be emitted and job should complete successfully
      refute_receive_event(CQRS, LeadUnified, fn ->
        # Act & Assert - job should return :ok (no retry for generic errors)
        assert :ok = perform_job(UnificationJob, args)
      end)
    end
  end
end
