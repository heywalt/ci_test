defmodule WaltUi.Projectors.ContactCreation do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: "contact_creation_projector",
    consistency: :strong

  require Logger

  alias CQRS.Leads
  alias WaltUi.Projections.ContactCreation

  project %Leads.Events.LeadCreated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :projection, fn _ ->
      ContactCreation.changeset(%{
        date: to_date(event.timestamp),
        type: :create,
        user_id: event.user_id
      })
    end)
  end

  # LeadDeleted events have not always included a user_id. Skip events that don't have one.
  project %Leads.Events.LeadDeleted{user_id: nil}, _metadata, fn multi ->
    multi
  end

  # LeadDeleted events have not always included a timestamp. Skip events that don't have one.
  project %Leads.Events.LeadDeleted{timestamp: nil}, _metadata, fn multi ->
    multi
  end

  project %Leads.Events.LeadDeleted{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :projection, fn _ ->
      ContactCreation.changeset(%{
        date: to_date(event.timestamp),
        type: :delete,
        user_id: event.user_id
      })
    end)
  end

  @impl Commanded.Event.Handler
  def error({:error, error}, event, _ctx) do
    Logger.error("Error encountered during contact creation projection",
      details: inspect(error),
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__
    )

    :skip
  end

  defp to_date(nil), do: Date.utc_today()

  defp to_date(%NaiveDateTime{} = ts) do
    case Date.new(ts.year, ts.month, ts.day) do
      {:ok, date} -> date
      _else -> Date.utc_today()
    end
  end

  defp to_date(ts) when is_binary(ts) do
    case NaiveDateTime.from_iso8601(ts) do
      {:ok, ts} -> to_date(ts)
      {:error, _} -> Date.utc_today()
    end
  end
end
