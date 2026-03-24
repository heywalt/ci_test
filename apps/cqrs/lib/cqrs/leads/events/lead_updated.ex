defmodule CQRS.Leads.Events.LeadUpdated do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :attrs, :map, enforce: true
    field :metadata, [map], enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :user_id, Ecto.UUID.t(), enforce: true
    field :version, integer, default: 1
  end
end
