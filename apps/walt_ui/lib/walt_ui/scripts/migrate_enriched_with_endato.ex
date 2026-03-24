defmodule WaltUi.Scripts.MigrateEnrichedWithEndato do
  @moduledoc """
  Script to migrate `provider_endato` records into `EnrichedWithEndato` events.
  """
  defmodule Job do
    @moduledoc false

    use Oban.Worker, max_attempts: 1, queue: :scripts

    @impl true
    def perform(%{args: %{"data" => list}}) do
      Enum.each(list, fn data ->
        CQRS.dispatch(%CQRS.Enrichments.Commands.EnrichWithEndato{
          id: UUID.uuid5(:oid, data["phone"]),
          addresses: get_address(data),
          emails: List.wrap(data["email"]),
          first_name: data["first_name"],
          last_name: data["last_name"],
          phone: data["phone"],
          timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
        })
      end)
    end

    defp get_address(%{"street_1" => street_1} = data) when not is_nil(street_1) do
      [
        %{
          street_1: street_1,
          street_2: data["street_2"],
          city: data["city"],
          state: data["state"],
          zip: data["zip"]
        }
      ]
    end

    defp get_address(_data), do: []
  end

  def run do
    stream =
      WaltUi.Providers.Endato
      |> Repo.stream()
      |> Stream.chunk_every(100)

    Repo.transaction(
      fn ->
        Enum.reduce(stream, 0, fn chunk, acc ->
          %{"data" => chunk}
          |> __MODULE__.Job.new(schedule_in: acc)
          |> Oban.insert()

          acc + 2
        end)
      end,
      timeout: :infinity
    )
  end
end
