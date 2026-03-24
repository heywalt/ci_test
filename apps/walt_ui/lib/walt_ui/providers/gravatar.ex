defmodule WaltUi.Providers.Gravatar do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [:email, :url, :unified_contact_id]

  @derive {Jason.Encoder, only: @fields}
  schema "provider_gravatar" do
    field :email, :string
    field :url, :string

    belongs_to :unified_contact, WaltUi.UnifiedRecords.Contact

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(record \\ %__MODULE__{}, attrs) do
    cast(record, attrs, @fields)
  end
end
