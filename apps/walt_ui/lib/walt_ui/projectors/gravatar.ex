defmodule WaltUi.Projectors.Gravatar do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: __MODULE__,
    start_from: :current,
    consistency: :strong

  require Logger

  alias CQRS.Enrichments.Events
  alias WaltUi.Projections.Gravatar

  project %Events.EnrichedWithEndato{} = evt, _metadata, fn multi ->
    case get_url(evt.emails) do
      {email, url} ->
        multi
        |> Ecto.Multi.put(:event_id, evt.id)
        |> Ecto.Multi.put(:email, email)
        |> Ecto.Multi.put(:url, url)
        |> Ecto.Multi.one(:gravatar, fn _ -> from g in Gravatar, where: g.id == ^evt.id end)
        |> Ecto.Multi.insert_or_update(:upsert, &upsert_record/1)

      _ ->
        multi
    end
  end

  @impl Commanded.Event.Handler
  def error(error, event, _ctx) do
    Logger.error("Error projecting Gravatar data",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(error)
    )

    :skip
  end

  defp get_url(emails) do
    emails
    |> Enum.map(fn email -> {email, WaltUi.Enrichment.Gravatar.get_url(email)} end)
    |> Enum.find(fn {_email, resp} -> match?({:ok, _}, resp) end)
    |> case do
      {email, {:ok, url}} -> {email, url}
      nil -> nil
    end
  end

  defp upsert_record(multi) do
    record = multi.gravatar || %Gravatar{id: multi.event_id}
    Gravatar.changeset(record, %{email: multi.email, url: multi.url})
  end
end
