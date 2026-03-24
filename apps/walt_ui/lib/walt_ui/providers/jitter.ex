defmodule WaltUi.Providers.Jitter do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields ~w(ptt unified_contact_id)a

  @derive {Jason.Encoder, only: @fields}
  schema "provider_jitter" do
    field :ptt, :integer
    belongs_to :unified_contact, WaltUi.UnifiedRecords.Contact

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(jitter \\ %__MODULE__{}, attrs) do
    cast(jitter, attrs, @fields)
  end
end
