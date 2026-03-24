defmodule WaltUi.Scripts.MigrateEnrichedWithFaraday do
  @moduledoc """
  Script to migrate `provider_faraday` records into `EnrichedWithFaraday` events.
  """
  defmodule Job do
    @moduledoc false

    use Oban.Worker, max_attempts: 1, queue: :scripts

    @impl true
    def perform(%{args: %{"data" => list}}) do
      Enum.each(list, fn data ->
        data
        |> normalize()
        |> then(&struct(CQRS.Enrichments.Commands.EnrichWithFaraday, &1))
        |> CQRS.dispatch()
      end)
    end

    defp normalize(data) do
      id = UUID.uuid5(:oid, data["phone"])
      ts = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      data = for {k, v} <- data, do: {String.to_atom(k), v}, into: %{}
      Map.merge(data, %{id: id, timestamp: ts})
    end
  end

  def run do
    stream =
      WaltUi.Providers.Faraday
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
end
