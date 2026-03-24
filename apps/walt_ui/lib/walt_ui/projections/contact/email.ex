defmodule WaltUi.Projections.Contact.Email do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :label, :string
    field :email, :string
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, [:label, :email])
    |> validate_required([:label, :email])
  end
end
