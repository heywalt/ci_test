defmodule WaltUi.Scripts.SyncEnrichment do
  @moduledoc """
  Script to sync enrichment updates made to `Providers.Endato` and `Providers.Faraday` records
  back to user contacts (`Projections.Contact`) attached to the same unified contact.
  """
  import Ecto.Query

  defmodule Job do
    @moduledoc false

    use Oban.Worker, max_attempts: 1, queue: :scripts

    @impl true
    def perform(%{args: %{"data" => list}}) do
      Enum.each(list, fn data ->
        CQRS.dispatch(%CQRS.Leads.Commands.Update{
          id: data["contact_id"],
          attrs: Map.update(data["attrs"], "ptt", 0, &trunc/1),
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
          user_id: data["user_id"]
        })
      end)
    end
  end

  def run do
    stream =
      sync_query()
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

  defp sync_query do
    from con in WaltUi.Projections.Contact,
      join: uni in assoc(con, :unified_contact),
      join: e in assoc(uni, :endato),
      join: f in assoc(uni, :faraday),
      select: %{
        contact_id: con.id,
        user_id: con.user_id,
        attrs: %{
          city: e.city,
          email: fragment("COALESCE(?, ?)", con.email, e.email),
          ptt: fragment("(COALESCE(?, 0) * 100)", f.propensity_to_transact),
          state: e.state,
          street_1: e.street_1,
          street_2: e.street_2,
          zip: e.zip
        }
      }
  end
end
