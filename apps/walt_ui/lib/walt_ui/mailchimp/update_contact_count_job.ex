defmodule WaltUi.Mailchimp.UpdateContactCountJob do
  @moduledoc """
  Oban job to update contact counts in Mailchimp for all users who created
  or deleted a contact yesterday.
  """
  use Oban.Worker, queue: :default

  import Ecto.Query

  @impl true
  def perform(_job) do
    user_contact_count_query()
    |> Repo.all()
    |> Enum.each(fn data ->
      WaltUi.Mailchimp.set_contact_count(data.email, data.count)
    end)
  end

  def user_contact_count_query do
    yesterday = Date.add(Date.utc_today(), -1)

    yesterdays_changes =
      from cc in WaltUi.Projections.ContactCreation,
        where: cc.date == ^yesterday,
        distinct: true,
        select: cc.user_id

    from u in WaltUi.Account.User,
      join: con in assoc(u, :contacts),
      where: u.id in subquery(yesterdays_changes),
      group_by: u.email,
      select: %{
        email: u.email,
        count: count(con.id)
      }
  end
end
