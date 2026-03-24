defmodule WaltUi.Email.SyncEmailJob do
  @moduledoc false

  use Oban.Worker, queue: :email_sync

  import Ecto.Query

  require Logger

  alias WaltUi.Email
  alias WaltUi.ExternalAccounts.ExternalAccount

  @impl true
  def perform(_job) do
    eas = external_accounts_to_sync()

    Logger.info("Starting Email Sync process for #{length(eas)} external accounts")

    Enum.each(eas, fn ea -> Email.sync_messages(ea) end)
  end

  defp external_accounts_to_sync do
    Repo.all(
      from ea in ExternalAccount,
        where:
          ea.provider in [:google] and not is_nil(ea.gmail_history_id) and not is_nil(ea.email),
        join: u in assoc(ea, :user),
        distinct: ea.id,
        preload: [user: {u, [:external_accounts]}]
    )
  end
end
