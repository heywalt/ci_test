defmodule WaltUi.Enrichment.Trestle.Client do
  @moduledoc """
  Context for interacting with Trestle.
  """
  alias Repo.Types.TenDigitPhone
  alias WaltUi.Enrichment.Trestle.Http

  @behaviour WaltUi.Enrichment.Trestle

  @impl true
  def search_by_phone(phone, opts \\ []) do
    case TenDigitPhone.cast(phone) do
      {:ok, formatted_phone} ->
        name_hint = extract_name_hint(opts)
        Http.search_by_phone(formatted_phone, name_hint: name_hint)

      :error ->
        {:error, "Invalid phone number format"}
    end
  end

  defp extract_name_hint(opts) do
    case Keyword.get(opts, :name_hint) do
      nil -> nil
      name -> sanitize(name)
    end
  end

  defp sanitize(value) do
    value
    |> RemoveEmoji.sanitize()
    |> String.trim()
  end
end
