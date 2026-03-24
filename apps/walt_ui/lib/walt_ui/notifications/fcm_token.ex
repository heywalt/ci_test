defmodule WaltUi.Notifications.FcmToken do
  @moduledoc """
  The FcmToken schema for storing Firebase Cloud Messaging device tokens.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Account.User

  @type t :: %__MODULE__{}

  @required [:token, :user_id]

  schema "fcm_tokens" do
    field :token, :string

    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(fcm_token, attrs) do
    fcm_token
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> unique_constraint(:token)
  end
end
