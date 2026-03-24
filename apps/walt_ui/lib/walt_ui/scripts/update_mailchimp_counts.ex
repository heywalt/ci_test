defmodule WaltUi.Scripts.UpdateMailchimpCounts do
  @moduledoc """
  Script to update contact count for all non-new users in Mailchimp.
  """
  import Ecto.Query

  alias WaltUi.Account.User
  alias WaltUi.Mailchimp

  def run do
    contact_count_per_email_query()
    |> Repo.all()
    |> Enum.each(&Mailchimp.set_contact_count(&1.email, &1.count))
  end

  defp contact_count_per_email_query do
    date = Date.utc_today()
    today = NaiveDateTime.new!(date.year, date.month, date.day, 0, 0, 0)

    from u in User,
      join: con in assoc(u, :contacts),
      where: u.inserted_at < ^today,
      group_by: u.email,
      select: %{
        email: u.email,
        count: count(con.id)
      }
  end
end
