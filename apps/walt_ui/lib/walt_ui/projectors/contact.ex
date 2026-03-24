defmodule WaltUi.Projectors.Contact do
  @moduledoc false

  use Commanded.Projections.Ecto,
    application: CQRS,
    repo: Repo,
    name: "contact_projector",
    consistency: :strong

  require Logger

  alias CQRS.Leads.Events
  alias Repo.Types.TenDigitPhone
  alias WaltUi.Projections.Contact

  project %Events.LeadCreated{} = event, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :projection, fn _ ->
      event
      |> Map.from_struct()
      |> normalize_phone_number()
      |> normalize_multiple_phone_numbers()
      |> Contact.changeset()
    end)
  end

  project %Events.LeadDeleted{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.one(:contact, fn _ -> from(c in Contact, where: c.id == ^event.id) end)
    |> Ecto.Multi.run(:delete, fn
      _repo, %{contact: nil} -> {:ok, :already_deleted}
      repo, %{contact: contact} -> repo.delete(contact)
    end)
  end

  project %Events.LeadUpdated{id: nil}, _metadata, fn multi ->
    multi
  end

  project %Events.LeadUpdated{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.one(:contact, fn _ -> from(c in Contact, where: c.id == ^event.id) end)
    |> Ecto.Multi.run(:update, fn
      _repo, %{contact: nil} ->
        {:ok, :not_found}

      repo, %{contact: contact} ->
        event.attrs
        |> normalize_phone_number()
        |> normalize_multiple_phone_numbers()
        |> then(&Contact.changeset(contact, &1))
        |> repo.update()
    end)
  end

  project %Events.LeadUnified{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.one(:contact, fn _ -> from c in Contact, where: c.id == ^event.id end)
    |> Ecto.Multi.run(:update, fn
      _repo, %{contact: nil} ->
        {:ok, :not_found}

      repo, %{contact: contact} ->
        attrs =
          event
          |> Map.take([
            :city,
            :enrichment_id,
            :enrichment_type,
            :ptt,
            :state,
            :street_1,
            :street_2,
            :zip
          ])
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)
          |> Map.new()

        contact
        |> Contact.changeset(attrs)
        |> repo.update()
    end)
  end

  project %Events.AddressSelected{} = event, _metadata, fn multi ->
    multi
    |> Ecto.Multi.one(:contact, fn _ -> from c in Contact, where: c.id == ^event.id end)
    |> Ecto.Multi.run(:update, fn
      _repo, %{contact: nil} ->
        {:ok, :not_found}

      repo, %{contact: contact} ->
        attrs = Map.take(event, [:street_1, :street_2, :city, :state, :zip])

        contact
        |> Contact.changeset(attrs)
        |> repo.update()
    end)
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

  defp normalize_phone_number(attrs) when is_map_key(attrs, :phone) do
    case TenDigitPhone.cast(attrs.phone) do
      {:ok, normalized} -> Map.put(attrs, :standard_phone, normalized)
      :error -> attrs
    end
  end

  defp normalize_phone_number(attrs), do: attrs

  defp normalize_multiple_phone_numbers(attrs) when is_map_key(attrs, :phone_numbers) do
    normalized_phone_numbers =
      Enum.map(attrs.phone_numbers, fn phone_number ->
        normalize_phone_number(phone_number)
      end)

    Map.put(attrs, :phone_numbers, normalized_phone_numbers)
  end

  defp normalize_multiple_phone_numbers(attrs), do: attrs
end
