defmodule CQRS.Meetings.MeetingAggregate do
  @moduledoc false

  use TypedStruct

  require Logger

  alias __MODULE__, as: Meeting
  alias CQRS.Meetings.Commands, as: Cmd
  alias CQRS.Meetings.Events

  defmodule Lifespan do
    @moduledoc false

    @behaviour Commanded.Aggregates.AggregateLifespan

    @impl true
    def after_command(_cmd), do: :infinity

    @impl true
    def after_event(_event), do: :infinity

    @impl true
    def after_error(error) do
      if is_exception(error) do
        {:stop, error}
      else
        :infinity
      end
    end
  end

  @derive Jason.Encoder
  typedstruct do
    field :attendees, List.t()
    field :calendar_id, Ecto.UUID.t(), enforce: true
    field :end_time, NaiveDateTime.t()
    field :id, Ecto.UUID.t(), enforce: true
    field :kind, String.t()
    field :link, String.t()
    field :location, String.t()
    field :name, String.t(), enforce: true
    field :source_id, String.t(), enforce: true
    field :start_time, NaiveDateTime.t()
    field :status, String.t()
    field :timestamp, NaiveDateTime.t()
    field :user_id, Ecto.UUID.t()
  end

  # Do not emit event if the meeting exists
  def execute(%Meeting{id: id}, %Cmd.Create{}) when not is_nil(id), do: :ok

  # emit created event if aggregate is new
  def execute(%Meeting{}, %Cmd.Create{} = cmd) do
    %Events.MeetingCreated{
      attendees: cmd.attendees,
      calendar_id: cmd.calendar_id,
      end_time: cmd.end_time,
      id: cmd.id,
      kind: cmd.kind,
      link: cmd.link,
      location: cmd.location,
      name: cmd.name,
      source_id: cmd.source_id,
      start_time: cmd.start_time,
      status: cmd.status,
      user_id: cmd.user_id
    }
  end

  def apply(%Meeting{}, %Events.MeetingCreated{} = event) do
    %Meeting{
      attendees: event.attendees,
      calendar_id: event.calendar_id,
      end_time: event.end_time,
      id: event.id,
      kind: event.kind,
      link: event.link,
      location: event.location,
      name: event.name,
      source_id: event.source_id,
      start_time: event.start_time,
      status: event.status,
      user_id: event.user_id
    }
  end
end
