defmodule CQRS.Leads.Events.PttJittered do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :score, :integer, enforce: true
    field :timestamp, :naive_datetime, enforce: true
    field :version, :integer, default: 1
  end
end
