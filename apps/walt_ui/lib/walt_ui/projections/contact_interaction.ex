defmodule WaltUi.Projections.ContactInteraction do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}

  @activity_types ~w(contact_created contact_invited contact_corresponded)a

  @required ~w(activity_type contact_id occurred_at)a
  @optional ~w(metadata)a

  @derive {Jason.Encoder, only: [:activity_type, :contact_id, :id, :metadata, :occurred_at]}
  schema "projection_contact_interactions" do
    field :activity_type, Ecto.Enum, values: @activity_types
    field :contact_id, :binary_id
    field :metadata, :map
    field :occurred_at, :naive_datetime

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(log \\ %__MODULE__{}, attrs) do
    log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end

  @spec interactions_for_contact_query(Ecto.UUID.t()) :: Ecto.Query.t()
  def interactions_for_contact_query(contact_id) do
    from ci in WaltUi.Projections.ContactInteraction,
      where: ci.contact_id == ^contact_id,
      order_by: [desc: ci.occurred_at]
  end
end
