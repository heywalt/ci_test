defmodule WaltUi.Calendars.Calendar do
  @moduledoc """
  The Calendar schema.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [:name, :source_id, :source, :user_id]
  @optional [:color, :timezone]

  schema "calendars" do
    field :color, :string
    field :name, :string
    field :source, Ecto.Enum, values: [:google]
    field :source_id, :string
    field :timezone, :string

    belongs_to :user, WaltUi.Account.User

    timestamps()
  end

  def changeset(calendar, attrs) do
    calendar
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
  end
end
