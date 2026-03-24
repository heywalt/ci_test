defmodule WaltUi.Handlers.EmailSyncOnContactUpdateTest do
  use WaltUi.CqrsCase, async: false
  use Mimic
  use Oban.Testing, repo: Repo

  alias CQRS.Leads.Events.LeadUpdated
  alias WaltUi.Email.SyncContactEmailsJob
  alias WaltUi.ExternalAccounts
  alias WaltUi.Handlers.EmailSyncOnContactUpdate

  setup :verify_on_exit!

  setup do
    Mimic.copy(WaltUi.ExternalAccounts)
    :ok
  end

  describe "handle/2" do
    test "enqueues email sync job when email field changes" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user_id = Ecto.UUID.generate()
        contact_id = Ecto.UUID.generate()
        external_account_id = Ecto.UUID.generate()

        external_account = %{id: external_account_id, user_id: user_id}

        expect(ExternalAccounts, :for_user_id, fn ^user_id, :google ->
          external_account
        end)

        event = %LeadUpdated{
          id: contact_id,
          user_id: user_id,
          attrs: %{"email" => "new@example.com"},
          metadata: [
            %{
              "field" => "email",
              "old_value" => "old@example.com",
              "new_value" => "new@example.com"
            }
          ],
          timestamp: ~N[2023-01-01 00:00:00]
        }

        metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

        assert :ok = EmailSyncOnContactUpdate.handle(event, metadata)

        assert_enqueued(
          worker: SyncContactEmailsJob,
          args: %{
            external_account_id: external_account_id,
            email_addresses: ["new@example.com"]
          }
        )
      end)
    end

    test "enqueues email sync job when emails field changes" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user_id = Ecto.UUID.generate()
        contact_id = Ecto.UUID.generate()
        external_account_id = Ecto.UUID.generate()

        external_account = %{id: external_account_id, user_id: user_id}

        expect(ExternalAccounts, :for_user_id, fn ^user_id, :google ->
          external_account
        end)

        event = %LeadUpdated{
          id: contact_id,
          user_id: user_id,
          attrs: %{"emails" => [%{"email" => "new@example.com", "label" => "work"}]},
          metadata: [
            %{
              "field" => "emails",
              "old_value" => [%{"email" => "old@example.com", "label" => "work"}],
              "new_value" => [%{"email" => "new@example.com", "label" => "work"}]
            }
          ],
          timestamp: ~N[2023-01-01 00:00:00]
        }

        metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

        assert :ok = EmailSyncOnContactUpdate.handle(event, metadata)

        assert_enqueued(
          worker: SyncContactEmailsJob,
          args: %{
            external_account_id: external_account_id,
            email_addresses: ["new@example.com"]
          }
        )
      end)
    end

    test "does not enqueue job when no email fields change" do
      user_id = Ecto.UUID.generate()
      contact_id = Ecto.UUID.generate()

      event = %LeadUpdated{
        id: contact_id,
        user_id: user_id,
        attrs: %{"first_name" => "John"},
        metadata: [
          %{
            "field" => "first_name",
            "old_value" => "Jane",
            "new_value" => "John"
          }
        ],
        timestamp: ~N[2023-01-01 00:00:00]
      }

      metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

      assert :ok = EmailSyncOnContactUpdate.handle(event, metadata)

      refute_enqueued(worker: SyncContactEmailsJob)
    end

    test "does not enqueue job when user has no Google external account" do
      user_id = Ecto.UUID.generate()
      contact_id = Ecto.UUID.generate()

      expect(ExternalAccounts, :for_user_id, fn ^user_id, :google ->
        nil
      end)

      event = %LeadUpdated{
        id: contact_id,
        user_id: user_id,
        attrs: %{"email" => "new@example.com"},
        metadata: [
          %{
            "field" => "email",
            "old_value" => "old@example.com",
            "new_value" => "new@example.com"
          }
        ],
        timestamp: ~N[2023-01-01 00:00:00]
      }

      metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

      assert :ok = EmailSyncOnContactUpdate.handle(event, metadata)

      refute_enqueued(worker: SyncContactEmailsJob)
    end

    test "handles atom field names in metadata" do
      Oban.Testing.with_testing_mode(:manual, fn ->
        user_id = Ecto.UUID.generate()
        contact_id = Ecto.UUID.generate()
        external_account_id = Ecto.UUID.generate()

        external_account = %{id: external_account_id, user_id: user_id}

        expect(ExternalAccounts, :for_user_id, fn ^user_id, :google ->
          external_account
        end)

        event = %LeadUpdated{
          id: contact_id,
          user_id: user_id,
          attrs: %{email: "new@example.com"},
          metadata: [
            %{
              "field" => :email,
              "old_value" => "old@example.com",
              "new_value" => "new@example.com"
            }
          ],
          timestamp: ~N[2023-01-01 00:00:00]
        }

        metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

        assert :ok = EmailSyncOnContactUpdate.handle(event, metadata)

        assert_enqueued(
          worker: SyncContactEmailsJob,
          args: %{
            external_account_id: external_account_id,
            email_addresses: ["new@example.com"]
          }
        )
      end)
    end

    test "handles empty metadata gracefully" do
      user_id = Ecto.UUID.generate()
      contact_id = Ecto.UUID.generate()

      event = %LeadUpdated{
        id: contact_id,
        user_id: user_id,
        attrs: %{"email" => "new@example.com"},
        metadata: [],
        timestamp: ~N[2023-01-01 00:00:00]
      }

      metadata = %{event_id: Ecto.UUID.generate(), correlation_id: Ecto.UUID.generate()}

      assert :ok = EmailSyncOnContactUpdate.handle(event, metadata)

      refute_enqueued(worker: SyncContactEmailsJob)
    end
  end
end
