defmodule CQRS.Leads.Events.LeadCreated do
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
    field :version, integer, default: 1
    field :zip, String.t()
  end
end
