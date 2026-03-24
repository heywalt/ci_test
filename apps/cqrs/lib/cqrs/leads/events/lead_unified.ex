defmodule CQRS.Leads.Events.LeadUnified do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :city, String.t()
    field :enrichment_id, Ecto.UUID.t(), enforce: true
    field :enrichment_type, :best | :lesser | nil
    field :ptt, integer, enforce: true
    field :state, String.t()
    field :street_1, String.t()
    field :street_2, String.t()
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer, default: 1
    field :zip, String.t()
  end
end
