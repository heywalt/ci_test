defmodule WaltUi.Projections.Endato do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset
  alias WaltUi.Projections.Endato.Address

  @type t :: %__MODULE__{}

  @required [:id, :phone]
  @optional [:emails, :first_name, :last_name, :quality_metadata]

  @derive {Jason.Encoder, except: [:__meta__, :__struct__]}
  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "projection_enrichments_endato" do
    field :emails, {:array, :string}, default: []
    field :first_name, :string
    field :last_name, :string
    field :phone, TenDigitPhone
    field :quality_metadata, :map

    embeds_many :addresses, Address, on_replace: :delete

    timestamps()
  end

  def changeset(endato \\ %__MODULE__{}, attrs) do
    endato
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> cast_embed(:addresses, with: &Address.changeset/2)
  end
end
