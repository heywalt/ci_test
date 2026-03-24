defmodule WaltUi.Scripts.MigrateUnifications do
  @moduledoc """
  Script to migrate `unified_contacts` into `LeadUnified` events.
  """
  import Ecto.Query

  defmodule Job do
    @moduledoc false

    use Oban.Worker, max_attempts: 1, queue: :scripts

    alias CQRS.Leads.Commands.Unify

    @impl true
    def perform(%{args: %{"data" => list}}) do
      Enum.each(list, fn data ->
        CQRS.dispatch(%Unify{
          id: data["contact_id"],
          enrichment_id: data["enrichment_id"],
          ptt: ptt(data["raw_ptt"])
        })
      end)
    end

    defp ptt(ptt) when is_integer(ptt), do: ptt
    defp ptt(ptt) when is_float(ptt), do: trunc(ptt * 100)
    defp ptt(_ptt), do: 0
  end

  def run do
    stream =
      contacts_to_unify_query()
      |> Repo.stream()
      |> Stream.chunk_every(100)

    Repo.transaction(
      fn ->
        Enum.reduce(stream, 0, fn chunk, acc ->
          %{"data" => chunk}
          |> __MODULE__.Job.new(schedule_in: acc)
          |> Oban.insert()

          acc + 1
        end)
      end,
      timeout: :infinity
    )
  end

  defp contacts_to_unify_query do
    from con in WaltUi.Projections.Contact,
      join: uni in assoc(con, :unified_contact),
      join: far in WaltUi.Projections.Faraday,
      on: far.phone == con.standard_phone,
      select: %{
        contact_id: con.id,
        enrichment_id: far.id,
        raw_ptt: far.propensity_to_transact
      }
  end
end
