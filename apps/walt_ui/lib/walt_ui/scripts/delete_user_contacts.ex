defmodule WaltUi.Scripts.DeleteUserContacts do
  @moduledoc false

  import Ecto.Query

  def run(user_id) do
    user_id
    |> contacts_query()
    |> Repo.all()
    |> Enum.each(&delete/1)
  end

  defp contacts_query(user_id) do
    from con in WaltUi.Projections.Contact, where: con.user_id == ^user_id
  end

  defp delete(contact) do
    CQRS.delete_contact(contact.id)
  end
end
