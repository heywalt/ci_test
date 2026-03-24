defmodule WaltUi.Projections.ContactCreation do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset
  import Ecto.Query

  @type t :: %__MODULE__{}
  @fields [:date, :type, :user_id]

  schema "projection_contact_creations" do
    field :date, :date
    field :type, Ecto.Enum, values: [:create, :delete]
    field :user_id, :binary_id

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(data \\ %__MODULE__{}, attrs) do
    data
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end

  @spec yesterdays_users_query() :: Ecto.Query.t()
  def yesterdays_users_query do
    yesterday = Date.add(Date.utc_today(), -1)

    from cc in __MODULE__,
      join: u in WaltUi.Account.User,
      on: u.id == cc.user_id,
      where: cc.date == ^yesterday,
      distinct: cc.user_id,
      select: %{
        id: cc.user_id,
        email: u.email
      }
  end
end
