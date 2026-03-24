defmodule WaltUi.Subscriptions.Subscription do
  @moduledoc """
  The Subscription schema.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [:user_id, :store]
  @optional [:expires_on, :store_customer_id, :store_subscription_id, :type]

  schema "subscriptions" do
    field :store_customer_id, :string
    field :store_subscription_id, :string
    field :store, Ecto.Enum, values: [:apple, :google, :stripe]
    field :expires_on, :date
    field :type, Ecto.Enum, values: [:monthly, :yearly], default: :monthly

    belongs_to :user, WaltUi.Account.User

    timestamps()
  end

  def changeset(contact_metadata, attrs) do
    contact_metadata
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
  end
end
