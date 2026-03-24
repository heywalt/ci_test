defmodule WaltUi.Scripts.DeleteEmptyFaradayRecords do
  @moduledoc false

  import Ecto.Query

  defmodule Job do
    @moduledoc false

    use Oban.Worker, max_attempts: 1, queue: :enrichment
    import Ecto.Query

    @impl true
    def perform(%{args: %{"ids" => faraday_ids}}) do
      Repo.delete_all(from(f in WaltUi.Providers.Faraday, where: f.id in ^faraday_ids))
      :ok
    end
  end

  def run do
    stream =
      empty_faraday_query()
      |> Repo.stream()
      |> Stream.chunk_every(250)

    Repo.transaction(fn ->
      Enum.reduce(stream, 0, fn chunk, acc ->
        %{"ids" => chunk}
        |> __MODULE__.Job.new(schedule_in: acc)
        |> Oban.insert()

        acc + 5
      end)
    end)
  end

  defp empty_faraday_query do
    from f in WaltUi.Providers.Faraday, where: is_nil(f.match_type), select: f.id
  end
end
