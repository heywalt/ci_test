defmodule WaltUi.Account.User do
  @moduledoc """
  The User schema.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @optional [
    :auth_uid,
    :avatar,
    :bio,
    :company_name,
    :first_name,
    :last_name,
    :phone,
    :tier,
    :type
  ]

  @required [:email]

  schema "users" do
    field :auth_uid, :string
    field :bio, :string
    field :company_name, :string
    field :contact_count, :integer, virtual: true
    field :email, :string
    field :first_name, :string
    field :is_admin, :boolean
    field :last_name, :string
    field :avatar, :string
    field :phone, :string
    field :tier, Ecto.Enum, values: [:freemium, :premium], default: :freemium
    field :type, Ecto.Enum, values: [:agent, :loan_officer, :title, :other]

    has_many :calendars, WaltUi.Calendars.Calendar
    has_many :contacts, WaltUi.Projections.Contact
    has_many :external_accounts, WaltUi.ExternalAccounts.ExternalAccount
    has_many :fcm_tokens, WaltUi.Notifications.FcmToken
    has_one :subscription, WaltUi.Subscriptions.Subscription

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
  end
end
