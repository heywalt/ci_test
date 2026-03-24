defmodule WaltUi.Calendars.SyncJob do
  @moduledoc false

  use Oban.Worker, queue: :calendar_sync

  import Ecto.Query

  alias WaltUi.Calendars
  alias WaltUi.ExternalAccounts.ExternalAccount

  @impl true
  def perform(_job) do
    eas = external_accounts_to_sync()

    Enum.each(eas, fn ea -> Calendars.sync(ea) end)
  end

  # NOTE: This will return all external accounts, with the user reloaded, and that users's calendars preloaded.
  defp external_accounts_to_sync do
    Repo.all(
      from ea in ExternalAccount,
        join: u in assoc(ea, :user),
        where: ea.provider in [:google],
        distinct: ea.id,
        preload: [user: {u, [:calendars]}]
    )
  end
end
