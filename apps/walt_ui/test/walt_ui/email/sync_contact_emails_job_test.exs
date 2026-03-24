defmodule WaltUi.Email.SyncContactEmailsJobTest do
  use WaltUi.CqrsCase, async: false
  use Mimic
  use Oban.Testing, repo: Repo

  alias WaltUi.Email.SyncContactEmailsJob
  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.Google.Gmail
  alias WaltUi.Google.Gmail.HistoricalSync.MessageProcessor

  setup :verify_on_exit!

  setup do
    Mimic.copy(WaltUi.ExternalAccounts)
    Mimic.copy(WaltUi.Google.Gmail)
    Mimic.copy(WaltUi.Google.Gmail.HistoricalSync.MessageProcessor)
    :ok
  end

  describe "perform/1" do
    test "syncs messages for specified email addresses" do
      external_account_id = Ecto.UUID.generate()
      email_addresses = ["test@example.com", "another@example.com"]

      external_account = %ExternalAccount{
        id: external_account_id,
        provider: :google,
        email: "user@example.com"
      }

      expect(ExternalAccounts, :get, fn ^external_account_id ->
        external_account
      end)

      expect(Gmail, :list_message_ids, fn ^external_account, _opts ->
        {:ok, %{"messages" => [%{"id" => "msg1"}, %{"id" => "msg2"}]}}
      end)

      expect(MessageProcessor, :process_all, fn ^external_account, ["msg1", "msg2"] ->
        :ok
      end)

      job_args = %{
        "external_account_id" => external_account_id,
        "email_addresses" => email_addresses
      }

      job = %Oban.Job{args: job_args}

      assert :ok = SyncContactEmailsJob.perform(job)
    end

    test "handles non-existent external account" do
      external_account_id = Ecto.UUID.generate()

      expect(ExternalAccounts, :get, fn ^external_account_id ->
        nil
      end)

      job_args = %{
        "external_account_id" => external_account_id,
        "email_addresses" => ["test@example.com"]
      }

      job = %Oban.Job{args: job_args}

      assert {:error, "External account not found"} = SyncContactEmailsJob.perform(job)
    end

    test "handles non-Google external account" do
      external_account_id = Ecto.UUID.generate()

      external_account = %ExternalAccount{
        id: external_account_id,
        provider: :skyslope,
        email: "user@example.com"
      }

      expect(ExternalAccounts, :get, fn ^external_account_id ->
        external_account
      end)

      job_args = %{
        "external_account_id" => external_account_id,
        "email_addresses" => ["test@example.com"]
      }

      job = %Oban.Job{args: job_args}

      assert {:error, :not_google} = SyncContactEmailsJob.perform(job)
    end

    test "handles empty email addresses list" do
      external_account_id = Ecto.UUID.generate()

      external_account = %ExternalAccount{
        id: external_account_id,
        provider: :google,
        email: "user@example.com"
      }

      expect(ExternalAccounts, :get, fn ^external_account_id ->
        external_account
      end)

      job_args = %{
        "external_account_id" => external_account_id,
        "email_addresses" => [nil, "", nil]
      }

      job = %Oban.Job{args: job_args}

      assert :ok = SyncContactEmailsJob.perform(job)
    end

    test "handles no messages found" do
      external_account_id = Ecto.UUID.generate()
      email_addresses = ["test@example.com"]

      external_account = %ExternalAccount{
        id: external_account_id,
        provider: :google,
        email: "user@example.com"
      }

      expect(ExternalAccounts, :get, fn ^external_account_id ->
        external_account
      end)

      expect(Gmail, :list_message_ids, fn ^external_account, _opts ->
        {:ok, %{}}
      end)

      job_args = %{
        "external_account_id" => external_account_id,
        "email_addresses" => email_addresses
      }

      job = %Oban.Job{args: job_args}

      assert :ok = SyncContactEmailsJob.perform(job)
    end
  end
end
