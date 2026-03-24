defmodule CQRS.Leads.Events.PttHistoryReset do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :reason, String.t()
  end
end
