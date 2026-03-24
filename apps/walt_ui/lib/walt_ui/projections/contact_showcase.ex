defmodule WaltUi.Projections.ContactShowcase do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields [:contact_id, :enrichment_type, :user_id]

  @derive Jason.Encoder
  schema "projection_contact_showcases" do
    field :contact_id, :binary_id
    field :enrichment_type, Ecto.Enum, values: [:best, :lesser]
    field :user_id, :binary_id

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(showcase \\ %__MODULE__{}, attrs) do
    cast(showcase, attrs, @fields)
  end
end
