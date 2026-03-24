defmodule WaltUi.Enrichment.UnificationCronJob do
  @moduledoc """
  This job finds all unenriched user contacts and schedules `UnificationSpawnJob`
  runs to attempt enrichment.
  """
  use Oban.Worker, max_attempts: 5, queue: :enrichment

  import Ecto.Query

  alias WaltUi.Enrichment.UnificationSpawnJob
  alias WaltUi.Projections.Contact

  @impl true
  def perform(_job) do
    stream =
      unenriched_user_contact_ids_query()
      |> Repo.stream()
      |> Stream.chunk_every(100)

    Repo.transaction(fn ->
      Enum.reduce(stream, 0, fn chunk, acc ->
        %{"ids" => chunk}
        |> UnificationSpawnJob.new(schedule_in: acc)
        |> Oban.insert()

        acc + 5
      end)
    end)
  end

  defp unenriched_user_contact_ids_query do
    from con in Contact, where: is_nil(con.unified_contact_id), select: con.id
  end
end
