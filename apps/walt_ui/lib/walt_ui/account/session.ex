defmodule WaltUi.Account.Session do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "sessions" do
    field :auth_data, :map
    field :expires_at, :naive_datetime

    belongs_to :user, WaltUi.Account.User

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:auth_data, :expires_at, :user_id])
    |> validate_required([:expires_at, :user_id])
  end

  def create_changeset(user, auth_data) do
    expires_at = NaiveDateTime.add(NaiveDateTime.utc_now(), 30 * 24 * 60 * 60, :second)

    %__MODULE__{}
    |> changeset(%{
      auth_data: auth_data,
      expires_at: expires_at,
      user_id: user.id
    })
  end
end
