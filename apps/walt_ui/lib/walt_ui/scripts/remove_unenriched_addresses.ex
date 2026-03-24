defmodule WaltUi.Scripts.RemoveUnenrichedAddresses do
  @moduledoc """
  Script to remove address data from user contacts that are not unified.
  """
  import Ecto.Query

  @spec run() :: :ok
  def run do
    contacts_query()
    |> Repo.all()
    |> Enum.each(fn contact ->
      CQRS.update_contact(contact, %{
        street_1: nil,
        street_2: nil,
        city: nil,
        state: nil,
        zip: nil
      })
    end)
  end

  defp contacts_query do
    from con in WaltUi.Projections.Contact,
      where: is_nil(con.unified_contact_id),
      where: not is_nil(con.street_1)
  end
end
