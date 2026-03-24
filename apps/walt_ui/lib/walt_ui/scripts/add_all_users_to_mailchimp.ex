defmodule WaltUi.Scripts.AddAllUsersToMailchimp do
  @moduledoc """
  Script to add existing users to our Mailchimp list.
  """
  import Ecto.Query

  alias WaltUi.Account.User
  alias WaltUi.Mailchimp

  def run do
    users_query()
    |> Repo.all()
    |> Enum.each(&Mailchimp.add_user_to_list/1)
  end

  defp users_query do
    from u in User, preload: :contacts
  end
end
