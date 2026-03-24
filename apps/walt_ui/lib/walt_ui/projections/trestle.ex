defmodule WaltUi.Projections.Trestle do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset
  alias WaltUi.Projections.Trestle.Address

  @type t :: %__MODULE__{}

  @required [:id, :phone]
  @optional [:age_range, :emails, :first_name, :last_name, :alternate_names, :quality_metadata]

  @derive {Jason.Encoder, except: [:__meta__, :__struct__]}
  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "projection_enrichments_trestle" do
    field :age_range, :string
    field :emails, {:array, :string}, default: []
    field :first_name, :string
    field :last_name, :string
    field :phone, TenDigitPhone
    field :alternate_names, {:array, :string}, default: []
    field :quality_metadata, :map

    embeds_many :addresses, Address, on_replace: :delete

    timestamps()
  end

  def changeset(trestle \\ %__MODULE__{}, attrs) do
    trestle
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> cast_embed(:addresses, with: &Address.changeset/2)
  end
end
