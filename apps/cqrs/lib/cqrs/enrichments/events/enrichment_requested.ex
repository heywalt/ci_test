defmodule CQRS.Enrichments.Events.EnrichmentRequested do
  @moduledoc false

  use TypedStruct

  alias Repo.Types.TenDigitPhone

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :email, String.t()
    field :first_name, String.t()
    field :last_name, String.t()
    field :phone, TenDigitPhone.t(), enforce: true
    field :user_id, Ecto.UUID.t(), enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :version, integer(), default: 1
  end
end
