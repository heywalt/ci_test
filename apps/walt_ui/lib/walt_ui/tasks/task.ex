defmodule WaltUi.Tasks.Task do
  @moduledoc """
  The Task schema.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [:description, :created_by, :user_id]
  @optional [
    :is_complete,
    :is_deleted,
    :is_expired,
    :due_at,
    :completed_at,
    :contact_id,
    :priority,
    :remind_at
  ]

  schema "tasks" do
    field :description, :string
    field :is_complete, :boolean, default: false
    field :is_deleted, :boolean, default: false
    field :is_expired, :boolean, default: false
    field :due_at, :naive_datetime
    field :completed_at, :utc_datetime_usec
    field :created_by, Ecto.Enum, values: [:system, :user]
    field :priority, Ecto.Enum, values: [:none, :low, :medium, :high], default: :none
    field :remind_at, :utc_datetime_usec

    belongs_to :user, WaltUi.Account.User
    belongs_to :contact, WaltUi.Projections.Contact

    timestamps()
  end

  def changeset(contact_metadata, attrs) do
    contact_metadata
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
  end
end
