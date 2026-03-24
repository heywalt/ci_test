defmodule WaltUi.Feedbacks.Feedback do
  @moduledoc """
  The Contact schema.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @optional [:comment]

  @required [:contact_id]

  schema "feedbacks" do
    field :comment, :string

    belongs_to :contact, WaltUi.Projections.Contact

    timestamps()
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
  end
end
