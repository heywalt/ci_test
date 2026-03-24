defmodule WaltUi.Scripts.DeleteEmptyUnifiedContacts do
  @moduledoc false

  import Ecto.Query

  defmodule Job do
    @moduledoc false

    use Oban.Worker, max_attempts: 1, queue: :unification

    import Ecto.Query
    alias WaltUi.UnifiedRecords

    @impl true
    def perform(%{args: %{"ids" => unified_contact_ids}}) do
      Repo.delete_all(from uni in UnifiedRecords.Contact, where: uni.id in ^unified_contact_ids)
      :ok
    end
  end

  def run do
    stream =
      empty_unified_contacts()
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

  defp empty_unified_contacts do
    from uni in WaltUi.UnifiedRecords.Contact,
      left_join: e in WaltUi.Providers.Endato,
      on: e.unified_contact_id == uni.id,
      where: is_nil(e.id),
      select: uni.id
  end
end
