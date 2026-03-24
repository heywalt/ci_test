defmodule CQRS.Leads.Events.LeadDeleted do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :timestamp, NaiveDateTime.t()
    field :user_id, Ecto.UUID.t()
    field :version, integer, default: 1
  end
end
