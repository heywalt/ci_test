defmodule WaltUi.Account.UpdateUserTierJob do
  @moduledoc """
  Oban job to update `User` tier based on `Subscription` expiration.
  """
  use Oban.Worker, queue: :user

  import Ecto.Query

  @impl true
  def perform(_job) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    Repo.update_all(
      expired_premium_users_query(),
      set: [
        tier: :freemium,
        updated_at: now
      ]
    )

    :ok
  end

  defp expired_premium_users_query do
    today = Date.utc_today()

    from user in WaltUi.Account.User,
      join: sub in assoc(user, :subscription),
      where: user.tier == :premium,
      where: sub.expires_on < ^today
  end
end
