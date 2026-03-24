defmodule WaltUi.Projectors.ContactShowcase do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: "contact_showcase_projector",
    consistency: :strong

  import Ecto.Query

  require Logger

  alias CQRS.Enrichments.Events.EnrichmentReset
  alias CQRS.Leads.Events
  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.ContactShowcase

  project(%Events.LeadUnified{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.put(:event, event)
    |> Ecto.Multi.put(:type, event.enrichment_type)
    |> Ecto.Multi.one(:contact, &contact_query/1)
    |> Ecto.Multi.run(:user_id, &user_id/2)
    |> Ecto.Multi.one(:best_count, &count_query(&1, :best))
    |> Ecto.Multi.one(:lesser_count, &count_query(&1, :lesser))
    |> Ecto.Multi.one(:csc, &showcase_query/1)
    |> Ecto.Multi.one(:swap_csc, &swap_query/1)
    |> Ecto.Multi.run(:action, &take_action/2)
    |> Ecto.Multi.run(:cleanup, &cleanup/2)
  end)

  project(%Events.LeadUpdated{} = event, _metadata, fn multi ->
    if type = event.attrs[:enrichment_type] do
      multi
      |> Ecto.Multi.put(:event, event)
      |> Ecto.Multi.put(:type, type)
      |> Ecto.Multi.run(:user_id, &user_id/2)
      |> Ecto.Multi.one(:best_count, &count_query(&1, :best))
      |> Ecto.Multi.one(:lesser_count, &count_query(&1, :lesser))
      |> Ecto.Multi.one(:csc, &showcase_query/1)
      |> Ecto.Multi.one(:swap_csc, &swap_query/1)
      |> Ecto.Multi.run(:action, &take_action/2)
      |> Ecto.Multi.run(:cleanup, &cleanup/2)
    else
      multi
    end
  end)

  project(%Events.LeadDeleted{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.put(:action, :ignore)
    |> Ecto.Multi.delete_all(:delete, fn _ ->
      from(csc in ContactShowcase, where: csc.contact_id == ^event.id)
    end)
  end)

  project(%EnrichmentReset{} = event, _metadata, fn multi ->
    Ecto.Multi.delete_all(
      multi,
      :delete_contact_showcases,
      from(cs in ContactShowcase,
        join: c in Contact,
        on: cs.contact_id == c.id,
        where: c.enrichment_id == ^event.id or is_nil(c.enrichment_id)
      )
    )
  end)

  @impl Commanded.Event.Handler
  def error({:error, %Ecto.Changeset{valid?: false} = cs}, event, _ctx) do
    Logger.error("Encountered invalid changeset during ContactShowcase projection",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(cs.errors)
    )

    :skip
  end

  def error({:error, reason}, event, _ctx) do
    Logger.error("Encountered unknown error during ContactShowcase projection",
      event_id: event.id,
      event_type: event.__struct__,
      module: __MODULE__,
      reason: inspect(reason)
    )

    :skip
  end

  defp cleanup(_repo, %{action: :swap, swap_csc: csc}) when not is_nil(csc) do
    Repo.delete(csc)
  end

  defp cleanup(_repo, _multi), do: {:ok, nil}

  defp contact_query(multi) do
    from(con in WaltUi.Projections.Contact, where: con.id == ^multi.event.id)
  end

  defp count_query(multi, type) do
    from(csc in ContactShowcase,
      where: csc.user_id == ^multi.user_id,
      where: csc.enrichment_type == ^type,
      select: count(csc)
    )
  end

  defp showcase_query(multi) do
    from(csc in ContactShowcase, where: csc.contact_id == ^multi.event.id)
  end

  defp swap_query(multi) do
    from(csc in ContactShowcase,
      where: csc.user_id == ^multi.user_id,
      where: csc.enrichment_type == :lesser,
      where: csc.contact_id != ^multi.event.id,
      order_by: fragment("RANDOM()"),
      limit: 1,
      select: csc
    )
  end

  # we have enough showcases, so do nothing
  defp take_action(_repo, %{best_count: 150}), do: {:ok, :ignore}

  # contact is already showcased and enrichment type has not changed, so do nothing
  defp take_action(_repo, %{csc: %{enrichment_type: type}, type: type}), do: {:ok, :ignore}

  # contact is already showcased but enrichment type has changed, so update enrichment type
  defp take_action(_repo, %{csc: csc, type: new_type}) when not is_nil(csc) do
    csc
    |> ContactShowcase.changeset(%{enrichment_type: new_type})
    |> Repo.update()

    {:ok, :ignore}
  end

  # we do not have enough showcases and contact is not showcased, so add showcase
  defp take_action(_repo, %{best_count: a, csc: nil, lesser_count: b} = multi)
       when a + b < 150 do
    %{contact_id: multi.event.id, enrichment_type: multi.type, user_id: multi.user_id}
    |> ContactShowcase.changeset()
    |> Repo.insert()
    |> case do
      {:ok, _} -> {:ok, :showcase}
      {:error, _} -> {:ok, :ignore}
    end
  end

  # we can swap a lesser enrichment showcase for a high quality enrichment
  defp take_action(_repo, %{type: type} = multi) when type in [:best, "best"] do
    %{contact_id: multi.event.id, enrichment_type: :best, user_id: multi.user_id}
    |> ContactShowcase.changeset()
    |> Repo.insert()
    |> case do
      {:ok, _} -> {:ok, :swap}
      {:error, _} -> {:ok, :ignore}
    end
  end

  # else, do nothing
  defp take_action(_repo, _multi), do: {:ok, :ignore}

  defp user_id(_repo, %{event: %{user_id: id}}), do: {:ok, id}
  defp user_id(_repo, %{contact: %{user_id: id}}), do: {:ok, id}
  defp user_id(_repo, _multi), do: {:error, :user_not_found}
end
