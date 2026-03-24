defmodule CQRS.Enrichments.Events.FaradayEnrichmentRequested do
  @moduledoc false

  use TypedStruct

  alias Repo.Types.TenDigitPhone

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :addresses, {:array, :map}
    field :age, integer | nil
    field :age_range, String.t()
    field :emails, {:array, :string}
    field :first_name, :string
    field :last_name, :string
    field :phone, TenDigitPhone.t(), enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer, default: 1
  end
end
