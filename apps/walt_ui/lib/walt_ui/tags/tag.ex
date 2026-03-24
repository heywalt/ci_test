defmodule WaltUi.Tags.Tag do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Account.User

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder, only: [:id, :name, :color, :inserted_at, :updated_at]}
  schema "tags" do
    field :name, :string
    field :color, :string
    belongs_to :user, User

    many_to_many :contacts, WaltUi.Projections.Contact, join_through: "contact_tags"

    timestamps()
  end

  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color, :user_id])
    |> validate_required([:name, :color, :user_id])
    |> unique_constraint([:user_id, :name], name: "tags_user_id_name_index")
  end
end
