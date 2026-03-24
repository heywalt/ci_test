defmodule WaltUi.Projectors.PttScore do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: "ptt_score_projector_2",
    consistency: :strong

  require Logger

  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Leads.Events
  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.PttScore

  project %Events.LeadCreated{} = event, _metadata, fn multi ->
    if zero?(event.ptt) do
      multi
    else
      Ecto.Multi.insert(multi, :ptt_score, fn _ ->
        PttScore.changeset(%{
          contact_id: event.id,
          occurred_at: event.timestamp,
          score: event.ptt,
          score_type: :ptt
        })
      end)
    end
  end

  project %Events.LeadUpdated{} = event, _metadata, fn multi ->
    if score = event.attrs[:ptt] do
      Ecto.Multi.insert(multi, :ptt_score, fn _ ->
        PttScore.changeset(%{
          contact_id: event.id,
          occurred_at: event.timestamp,
          score: score,
          score_type: :ptt
        })
      end)
    else
      multi
    end
  end

  project %Events.LeadUnified{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :ptt_score, fn _ ->
      PttScore.changeset(%{
        contact_id: event.id,
        occurred_at: event.timestamp,
        score: event.ptt,
        score_type: :ptt
      })
    end)
  end

  project %Events.LeadDeleted{} = event, _metadata, fn multi ->
    delete_all(multi, event.id)
  end

  project %Events.PttJittered{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :jitter_score, fn _ ->
      PttScore.changeset(%{
        contact_id: event.id,
        occurred_at: event.timestamp,
        score: event.score,
        score_type: :jitter
      })
    end)
  end

  project %Events.PttHistoryReset{} = event, _metadata, fn multi ->
    delete_all(multi, event.id)
  end

  project %EnrichmentComposed{} = event, _metadata, fn multi ->
    case Map.get(event.composed_data, :ptt) do
      ptt when is_nil(ptt) or ptt == 0 ->
        multi

      ptt ->
        # Find all contacts linked to this enrichment
        contact_query = from c in Contact, where: c.enrichment_id == ^event.id, select: c.id

        multi
        |> Ecto.Multi.all(:contacts, contact_query)
        |> Ecto.Multi.run(:insert_ptt_scores, fn repo, %{contacts: contact_ids} ->
          Logger.info("Move Score projection",
            event_id: event.id,
            ptt_score: ptt,
            contact_count: length(contact_ids),
            module: __MODULE__
          )

          # Create Move Score entries for each linked contact
          entries =
            Enum.map(contact_ids, fn contact_id ->
              %{
                id: Ecto.UUID.generate(),
                contact_id: contact_id,
                occurred_at: parse_timestamp(event.timestamp),
                score: ptt,
                score_type: :ptt,
                inserted_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
                updated_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
              }
            end)

          case repo.insert_all(PttScore, entries) do
            {_count, _} -> {:ok, :inserted}
            error -> error
          end
        end)
    end
  end

  @impl Commanded.Event.Handler
  def error({:error, %Ecto.Changeset{valid?: false} = cs}, event, _ctx) do
    Logger.error("Encountered invalid changeset during projection",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(cs.errors)
    )

    :skip
  end

  def error({:error, reason}, event, _ctx) do
    Logger.error("Encountered unknown error during projection",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(reason)
    )

    :skip
  end

  defp delete_all(multi, id) do
    Ecto.Multi.delete_all(multi, :delete, fn _ ->
      from ptt in PttScore, where: ptt.contact_id == ^id
    end)
  end

  defp zero?(nil), do: true
  defp zero?(0), do: true
  defp zero?(_), do: false

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    timestamp
    |> NaiveDateTime.from_iso8601!()
    |> NaiveDateTime.truncate(:second)
  end

  defp parse_timestamp(%NaiveDateTime{} = timestamp) do
    NaiveDateTime.truncate(timestamp, :second)
  end
end
