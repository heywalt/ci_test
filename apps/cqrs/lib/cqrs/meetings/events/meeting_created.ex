defmodule CQRS.Meetings.Events.MeetingCreated do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :attendees, list()
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
    field :user_id, Ecto.UUID.t(), enforce: true
    field :version, integer, default: 1
  end
end
