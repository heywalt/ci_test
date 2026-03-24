defmodule WaltUi.Scripts.User.RequestEnrichments do
  @moduledoc """
  Script to request composable enrichment for all of a user's contacts.

  Finds all contacts for the given user_id that have a standard_phone value,
  then dispatches RequestEnrichment commands for those contacts.
  """
  import Ecto.Query

  alias CQRS.Enrichments.Commands.RequestEnrichment
  alias WaltUi.Projections.Contact

  def run(user_id) do
    user_id
    |> find_contacts_with_phone()
    |> Enum.each(fn contact ->
      command =
        RequestEnrichment.new(%{
          phone: contact.phone,
          first_name: contact.first_name,
          last_name: contact.last_name,
          email: contact.email,
          user_id: contact.user_id
        })

      CQRS.dispatch(command)
    end)
  end

  defp find_contacts_with_phone(user_id) do
    Repo.all(
      from(c in Contact,
        where:
          c.user_id == ^user_id and
            not is_nil(c.standard_phone),
        select: %{
          phone: c.standard_phone,
          first_name: c.first_name,
          last_name: c.last_name,
          email: c.email,
          user_id: c.user_id
        }
      )
    )
  end
end
