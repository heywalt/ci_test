defmodule CQRS do
  @moduledoc """
  Commanded application for our event sourcing system.
  """
  use Commanded.Application, otp_app: :cqrs

  alias CQRS.Leads
  alias CQRS.Meetings

  router CQRS.Router

  @spec create_contact(map, Keyword.t()) :: {:ok, Leads.LeadAggregate.t()} | {:error, term}
  def create_contact(attrs, opts \\ []) do
    uuid = UUID.uuid5(:oid, "#{attrs[:user_id]}:#{attrs[:remote_source]}:#{attrs[:remote_id]}")
    {ts, attrs} = Map.pop_lazy(attrs, :timestamp, &timestamp/0)

    attrs
    |> Map.merge(%{id: uuid, timestamp: ts})
    |> then(&struct(Leads.Commands.Create, &1))
    |> CQRS.dispatch(Keyword.merge(opts, returning: :aggregate_state))
  end

  @spec update_contact(struct, map, Keyword.t()) ::
          {:ok, Leads.LeadAggregate.t()} | {:error, term}
  def update_contact(contact, attrs, opts \\ []) do
    {ts, attrs} = Map.pop_lazy(attrs, :timestamp, &timestamp/0)

    CQRS.dispatch(
      %Leads.Commands.Update{
        id: contact.id,
        attrs: attrs,
        timestamp: ts,
        user_id: contact.user_id
      },
      Keyword.merge(opts, returning: :aggregate_state)
    )
  end

  @spec delete_contact(Ecto.UUID.t(), Keyword.t()) :: :ok | {:error, term}
  def delete_contact(contact_id, opts \\ []) do
    CQRS.dispatch(%Leads.Commands.Delete{id: contact_id}, opts)
  end

  @spec jitter_contact_ptt(struct, map) :: :ok | {:error, term}
  def jitter_contact_ptt(contact, attrs) do
    {ts, attrs} = Map.pop_lazy(attrs, :timestamp, &timestamp/0)
    CQRS.dispatch(%Leads.Commands.JitterPtt{id: contact.id, score: attrs.score, timestamp: ts})
  end

  @spec create_meeting(map) :: {:ok, map} | {:error, term}
  def create_meeting(attrs) do
    # NOTE: This is the id of the calendar event/meeting that we get from the provider (i.e. Google)
    # just turned into a UUID.
    uuid = UUID.uuid5(:oid, "#{attrs[:id]}")

    CQRS.dispatch(
      %Meetings.Commands.Create{
        attendees: Map.get(attrs, :attendees),
        calendar_id: attrs.calendar_id,
        end_time: attrs.end_time,
        id: uuid,
        kind: attrs.kind,
        link: attrs.htmlLink,
        location: Map.get(attrs, :location),
        name: Map.get(attrs, :summary),
        source_id: attrs.id,
        start_time: attrs.start_time,
        status: attrs.status,
        user_id: attrs.user_id
      },
      returning: :aggregate_state
    )
  end

  @doc """
  Creates correspondence events for one or more contacts.
  """
  @spec create_correspondence(map()) :: list({:ok, term()} | {:error, term()})
  def create_correspondence(%{contact_ids: [_ | _] = contact_ids} = attrs) do
    Enum.map(contact_ids, fn contact_id ->
      CQRS.dispatch(
        %Leads.Commands.Correspond{
          meeting_time: attrs.meeting_time,
          id: contact_id,
          message_link: attrs.message_link,
          direction: attrs.direction,
          from: attrs.from,
          to: attrs.to,
          source: attrs.source,
          source_id: attrs.id,
          source_thread_id: attrs.thread_id,
          subject: attrs.subject,
          user_id: attrs.user_id
        },
        returning: :aggregate_state
      )
    end)
  end

  @spec select_address(Ecto.UUID.t(), map, Keyword.t()) :: :ok
  def select_address(id, address, opts \\ []) do
    CQRS.dispatch(
      %Leads.Commands.SelectAddress{
        id: id,
        street_1: address.street_1,
        street_2: address.street_2,
        city: address.city,
        state: address.state,
        zip: address.zip
      },
      opts
    )
  end

  defp timestamp do
    NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
  end
end
