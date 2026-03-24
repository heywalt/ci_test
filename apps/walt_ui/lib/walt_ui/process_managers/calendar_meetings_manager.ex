defmodule WaltUi.ProcessManagers.CalendarMeetingsManager do
  @moduledoc false

  use Commanded.ProcessManagers.ProcessManager,
    application: CQRS,
    name: __MODULE__

  use TypedStruct

  require Logger

  alias __MODULE__
  alias CQRS.Leads.Commands.InviteContact
  alias CQRS.Meetings.Events.MeetingCreated
  alias WaltUi.Contacts

  @derive Jason.Encoder
  typedstruct do
    field :calendar_id, Ecto.UUID.t(), enforce: true
    field :id, Ecto.UUID.t(), enforce: true
    field :name, String.t(), enforce: true
    field :source_id, String.t(), enforce: true
    field :user_id, :binary_id
  end

  # Start a new instace of the process manager for the calendar event
  def interested?(%MeetingCreated{id: id}) do
    {:start, id}
  end

  def interested?(_event), do: false

  def handle(%CalendarMeetingsManager{}, %MeetingCreated{attendees: []}), do: []
  def handle(%CalendarMeetingsManager{}, %MeetingCreated{attendees: nil}), do: []

  def handle(%CalendarMeetingsManager{}, %MeetingCreated{attendees: attendees} = event) do
    contact_ids =
      Enum.flat_map(attendees, fn %{email: email} ->
        Contacts.get_by_email(event.user_id, email)
      end)

    Enum.map(contact_ids, fn contact_id ->
      event
      |> Map.from_struct()
      |> Map.drop([:attendees])
      |> Map.put(:id, contact_id)
      |> Map.put(:meeting_id, event.id)
      |> InviteContact.new()
    end)
  end

  # By default skip any problematic events
  def error(error, _command_or_event, _failure_context) do
    Logger.error(fn -> "#{__MODULE__} encountered an error: " <> inspect(error) end)

    :skip
  end
end
