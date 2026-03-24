defmodule WaltUi.Projections.Jitter do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [:id, :ptt]

  @derive {Jason.Encoder, except: [:__meta__, :__struct__]}
  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "projection_jitters" do
    field :ptt, :integer
    timestamps()
  end

  def changeset(jitter \\ %__MODULE__{}, attrs) do
    jitter
    |> cast(attrs, @required)
    |> validate_required(@required)
  end
end
