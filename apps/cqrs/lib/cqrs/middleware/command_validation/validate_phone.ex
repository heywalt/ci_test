defmodule CQRS.Middleware.CommandValidation.ValidatePhone do
  @moduledoc false

  import Ecto.Changeset

  @bogus_phone_codes ["800", "833", "844", "855", "866", "877", "888", "900"]

  @spec run(Ecto.Changeset.t()) :: Keyword.t()
  def run(changeset) do
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
