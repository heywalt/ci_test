defmodule WaltUi.Projectors.ContactInteraction do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: "contact_interaction_projector",
    consistency: :strong

  alias CQRS.Leads
  alias WaltUi.Projections.ContactInteraction

  project %Leads.Events.LeadCreated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :projection, fn _ ->
      ContactInteraction.changeset(%{
        activity_type: :contact_created,
        contact_id: event.id,
        occurred_at: event.timestamp
      })
    end)
  end

  project %Leads.Events.LeadDeleted{} = event, _metadata, fn multi ->
    Ecto.Multi.delete_all(multi, :projection, fn _ ->
      from(ci in ContactInteraction, where: ci.contact_id == ^event.id)
    end)
  end

  project %Leads.Events.ContactInvited{} = event, _metadata, fn multi ->
    metadata = Map.drop(event, [:__struct__, :id, :version])

    Ecto.Multi.insert(multi, :projection, fn _ ->
      ContactInteraction.changeset(%{
        activity_type: :contact_invited,
        metadata: metadata,
        occurred_at: event.start_time,
        contact_id: event.id
      })
    end)
  end

  project %Leads.Events.ContactCorresponded{} = event, _metadata, fn multi ->
    metadata = Map.drop(event, [:__struct__, :id, :version])

    Ecto.Multi.insert(multi, :projection, fn _ ->
      ContactInteraction.changeset(%{
        activity_type: :contact_corresponded,
        contact_id: event.id,
        occurred_at: event.meeting_time,
        metadata: metadata
      })
    end)
  end
end
