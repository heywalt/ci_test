defmodule WaltUi.ContactTags.ContactTag do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Account.User
  alias WaltUi.Tags.Tag

  @type t :: %__MODULE__{}

  @derive {Jason.Encoder, only: [:id, :contact_id, :tag_id, :inserted_at, :updated_at]}
  schema "contact_tags" do
    belongs_to :user, User
    field :contact_id, :binary_id
    belongs_to :tag, Tag

    timestamps()
  end

  def changeset(contact_tag, attrs) do
    contact_tag
    |> cast(attrs, [:user_id, :contact_id, :tag_id])
    |> validate_required([:user_id, :contact_id, :tag_id])
    |> unique_constraint([:contact_id, :tag_id], name: "contact_tags_contact_id_tag_id_index")
    |> foreign_key_constraint(:tag_id)
    |> foreign_key_constraint(:user_id)
  end
end
