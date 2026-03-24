defmodule WaltUi.ExternalAccounts.ExternalAccount do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required [
    :access_token,
    :expires_at,
    :provider,
    :refresh_token,
    :token_source,
    :user_id
  ]

  @optional [:email, :provider_user_id, :gmail_history_id, :historical_sync_metadata]

  @derive {Jason.Encoder,
           only: [:id, :provider, :access_token, :refresh_token, :expires_at, :user_id]}

  schema "external_accounts" do
    field :access_token, :string
    field :email, :string
    field :expires_at, :utc_datetime_usec
    field :gmail_history_id, :string
    field :historical_sync_metadata, :map, default: %{}
    field :provider, Ecto.Enum, values: [:google, :skyslope]
    field :provider_user_id, :string
    field :refresh_token, :string
    field :token_source, Ecto.Enum, values: [:android, :ios, :web]

    belongs_to :user, WaltUi.Account.User

    timestamps()
  end

  @doc false
  def changeset(external_account, attrs) do
    external_account
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
  end
end
