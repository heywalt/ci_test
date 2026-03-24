defmodule CQRS.Leads.Events.ContactCorresponded do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :direction, String.t()
    field :from, String.t()
    field :id, Ecto.UUID.t(), enforce: true
    field :meeting_time, NaiveDateTime.t()
    field :message_link, String.t()
    field :source, String.t()
    field :source_id, String.t()
    field :source_thread_id, String.t()
    field :subject, String.t()
    field :to, String.t()
    field :user_id, Ecto.UUID.t(), enforce: true
    field :version, integer, default: 1
  end
end
