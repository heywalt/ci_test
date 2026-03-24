defmodule WaltUi.Projections.Gravatar do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [:id, :email, :url]

  @derive {Jason.Encoder, except: [:__meta__, :__struct__]}
  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "projection_enrichments_gravatar" do
    field :email, :string
    field :url, :string

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(record \\ %__MODULE__{}, attrs) do
    record
    |> cast(attrs, @required)
    |> validate_required(@required)
  end
end
