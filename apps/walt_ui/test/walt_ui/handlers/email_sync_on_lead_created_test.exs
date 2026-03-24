defmodule WaltUi.Handlers.EmailSyncOnLeadCreatedTest do
  use WaltUi.CqrsCase, async: false
  use Mimic
  use Oban.Testing, repo: Repo

  alias CQRS.Leads.Events.LeadCreated
  alias WaltUi.Email.SyncContactEmailsJob
  alias WaltUi.ExternalAccounts
  alias WaltUi.Handlers.EmailSyncOnLeadCreated

  setup :verify_on_exit!

  setup do
    Mimic.copy(WaltUi.ExternalAccounts)
    :ok
  end

  describe "handle/2" do
    test "enqueues email sync job when lead created with email field" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user_id = Ecto.UUID.generate()
        contact_id = Ecto.UUID.generate()
        external_account_id = Ecto.UUID.generate()

        external_account = %{id: external_account_id, user_id: user_id}

        expect(ExternalAccounts, :for_user_id, fn ^user_id, :google ->
          external_account
        end)

        event = %LeadCreated{
          id: contact_id,
          user_id: user_id,
          email: "new@example.com",
          phone: "555-1234",
          timestamp: ~N[2023-01-01 00:00:00]
        }

        metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

        assert :ok = EmailSyncOnLeadCreated.handle(event, metadata)

        assert_enqueued(
          worker: SyncContactEmailsJob,
          args: %{
            external_account_id: external_account_id,
            email_addresses: ["new@example.com"]
          }
        )
      end)
    end

    test "enqueues email sync job when lead created with emails field" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user_id = Ecto.UUID.generate()
        contact_id = Ecto.UUID.generate()
        external_account_id = Ecto.UUID.generate()

        external_account = %{id: external_account_id, user_id: user_id}

        expect(ExternalAccounts, :for_user_id, fn ^user_id, :google ->
          external_account
        end)

        event = %LeadCreated{
          id: contact_id,
          user_id: user_id,
          emails: [%{"email" => "work@example.com", "label" => "work"}],
          phone: "555-1234",
          timestamp: ~N[2023-01-01 00:00:00]
        }

        metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

        assert :ok = EmailSyncOnLeadCreated.handle(event, metadata)

        assert_enqueued(
          worker: SyncContactEmailsJob,
          args: %{
            external_account_id: external_account_id,
            email_addresses: ["work@example.com"]
          }
        )
      end)
    end

    test "does not enqueue job when lead created without email fields" do
      user_id = Ecto.UUID.generate()
      contact_id = Ecto.UUID.generate()

      event = %LeadCreated{
        id: contact_id,
        user_id: user_id,
        first_name: "John",
        last_name: "Doe",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

      assert :ok = EmailSyncOnLeadCreated.handle(event, metadata)

      refute_enqueued(worker: SyncContactEmailsJob)
    end

    test "does not enqueue job when user has no Google external account" do
      user_id = Ecto.UUID.generate()
      contact_id = Ecto.UUID.generate()

      expect(ExternalAccounts, :for_user_id, fn ^user_id, :google ->
        nil
      end)

      event = %LeadCreated{
        id: contact_id,
        user_id: user_id,
        email: "new@example.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

      assert :ok = EmailSyncOnLeadCreated.handle(event, metadata)

      refute_enqueued(worker: SyncContactEmailsJob)
    end

    test "handles both email and emails fields together" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user_id = Ecto.UUID.generate()
        contact_id = Ecto.UUID.generate()
        external_account_id = Ecto.UUID.generate()

        external_account = %{id: external_account_id, user_id: user_id}

        expect(ExternalAccounts, :for_user_id, fn ^user_id, :google ->
          external_account
        end)

        event = %LeadCreated{
          id: contact_id,
          user_id: user_id,
          email: "primary@example.com",
          emails: [
            %{"email" => "work@example.com", "label" => "work"},
            %{"email" => "personal@example.com", "label" => "personal"}
          ],
          phone: "555-1234",
          timestamp: ~N[2023-01-01 00:00:00]
        }

        metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

        assert :ok = EmailSyncOnLeadCreated.handle(event, metadata)

        assert_enqueued(
          worker: SyncContactEmailsJob,
          args: %{
            external_account_id: external_account_id,
            email_addresses: ["primary@example.com", "work@example.com", "personal@example.com"]
          }
        )
      end)
    end
  end
end
