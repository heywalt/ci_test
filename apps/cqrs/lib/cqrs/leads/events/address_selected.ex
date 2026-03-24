defmodule CQRS.Leads.Events.AddressSelected do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :street_1, String.t(), enforce: true
    field :street_2, String.t() | nil
    field :city, String.t(), enforce: true
    field :state, String.t(), enforce: true
    field :zip, String.t(), enforce: true
    field :version, integer, default: 1
  end
end
