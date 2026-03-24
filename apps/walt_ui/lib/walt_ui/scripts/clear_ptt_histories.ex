defmodule WaltUi.Scripts.ClearPttHistories do
  @moduledoc """
  Script to clear user contact Move Score history via unified contacts
  without Faraday enrichment.
  """
  import Ecto.Query

  alias CQRS.Leads.Commands.ResetPttHistory

  @spec run() :: :ok
  def run do
    contact_ids_query()
    |> Repo.all()
    |> Enum.each(fn id ->
      CQRS.dispatch(%ResetPttHistory{id: id, reason: "Faraday record discarded"})
    end)
  end

  defp contact_ids_query do
    from con in WaltUi.Projections.Contact,
      inner_join: uni in assoc(con, :unified_contact),
      left_join: f in assoc(uni, :faraday),
      where: is_nil(f.id),
      select: con.id
  end
end
