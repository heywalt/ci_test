defmodule CQRS.Enrichments.Events.EnrichedWithTrestle do
  @moduledoc false

  use TypedStruct

  alias Repo.Types.TenDigitPhone

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :addresses, [map()], default: []
    field :age_range, String.t()
    field :emails, [String.t()], default: []
    field :first_name, String.t()
    field :last_name, String.t()
    field :phone, TenDigitPhone.t(), enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer(), default: 1
  end
end
