defmodule WaltUi.Projections.Contact.PhoneNumber do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @derive Jason.Encoder
  embedded_schema do
    field :label, :string
    field :phone, :string
    field :standard_phone, :string
  end

  def changeset(phone_number, attrs) do
    phone_number
    |> cast(attrs, [:label, :phone, :standard_phone])
    |> validate_required([:label, :phone])
    |> validate_phone()
  end

  @bogus_phone_codes ["800", "833", "844", "855", "866", "877", "888", "900"]

  def validate_phone(changeset) do
    validate_change(changeset, :phone, fn :phone, phone ->
      trimmed =
        phone
        |> to_string()
        |> String.replace("+1", "")
        |> String.trim()

      if String.starts_with?(trimmed, @bogus_phone_codes) do
        [phone: "contains a commercial area code"]
      else
        []
      end
    end)
  end
end
