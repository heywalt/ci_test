defmodule WaltUi.Scripts.MigrateAddressToContactProjection do
  @moduledoc """
  Script to migrate Endato address data to user contact projections
  that are unified to that same data.
  """
  import Ecto.Query

  @spec run() :: :ok
  def run do
    contacts_query()
    |> Repo.all()
    |> Enum.each(fn data ->
      attrs = Map.take(data.endato, [:street_1, :street_2, :city, :state, :zip])
      CQRS.update_contact(data.contact, attrs)
    end)
  end

  defp contacts_query do
    from con in WaltUi.Projections.Contact,
      inner_join: uni in assoc(con, :unified_contact),
      inner_join: en in assoc(uni, :endato),
      where: is_nil(con.street_1),
      where: not is_nil(en.street_1),
      select: %{contact: con, endato: en}
  end
end
