defmodule CQRS.Leads.Commands.Create do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :anniversary, Date.t()
    field :avatar, String.t()
    field :birthday, Date.t()
    field :city, String.t()
    field :date_of_home_purchase, Date.t()
    field :email, String.t()
    field :emails, {:array, :map}, default: []
    field :first_name, String.t()
    field :is_favorite, boolean, default: false
    field :last_name, String.t()
    field :phone, String.t(), enforce: true
    field :phone_numbers, {:array, :map}, default: []
    field :ptt, integer, default: 0
    field :remote_id, String.t()
    field :remote_source, String.t()
    field :state, String.t()
    field :street_1, String.t()
    field :street_2, String.t()
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :unified_contact_id, Ecto.UUID.t()
    field :user_id, Ecto.UUID.t(), enforce: true
    field :zip, String.t()
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset
    alias CQRS.Middleware.CommandValidation.ValidatePhone

    def certify(cmd) do
      types = %{
        id: :binary_id,
        anniversary: :date,
        avatar: :string,
        birthday: :date,
        city: :string,
        date_of_home_purchase: :date,
        email: :string,
        first_name: :string,
        is_favorite: :boolean,
        last_name: :string,
        phone: :string,
        ptt: :integer,
        remote_id: :string,
        remote_source: :string,
        state: :string,
        street_1: :string,
        street_2: :string,
        timestamp: :naive_datetime,
        unified_contact_id: :binary_id,
        user_id: :binary_id,
        zip: :string
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :phone, :timestamp, :user_id])
      |> validate_length(:email, max: 254)
      |> ValidatePhone.run()
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
