defmodule WaltUi.Enrichment.Endato.Client do
  @moduledoc """
  Context for interacting with Endato.
  """
  alias WaltUi.Directory
  alias WaltUi.Enrichment.Endato.Http
  alias WaltUi.Error

  @behaviour WaltUi.Enrichment.Endato

  @impl true
  def fetch_contact(contact) do
    case format_contact_request(contact) do
      {:ok, request} ->
        Http.fetch_contact(request)

      {:error, contact} ->
        {:error, contact}
    end
  end

  @impl true
  def search_by_phone(phone) do
    case format_phone(phone) do
      {:ok, formatted_phone} ->
        Http.search_by_phone(formatted_phone)

      {:error, error} ->
        {:error, error}
    end
  end

  defp format_contact_request(contact) do
    with {:ok, person} <- format_person(contact),
         {:ok, address} <- format_address(contact) do
      {:ok, Map.merge(person, address)}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp format_person(%{last_name: nil}) do
    {:error, "Last name is required"}
  end

  defp format_person(%{phone: nil}) do
    {:error, "Phone is required"}
  end

  defp format_person(contact) do
    person = %{
      FirstName: sanitize(contact.first_name),
      LastName: sanitize(contact.last_name),
      Email: contact.email,
      Phone: String.replace(to_string(contact.phone), ~r/[^0-9]/, "")
    }

    person
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
    |> then(&{:ok, &1})
  end

  defp format_address(%{street_1: nil}), do: {:ok, %{}}

  defp format_address(contact) when is_map_key(contact, :street_1) do
    {:ok,
     %{
       Address: %{
         addressLine1: Directory.house_number_and_street(contact),
         addressLine2: Directory.city_state_zip(contact)
       }
     }}
  end

  defp format_address(_), do: {:ok, %{}}

  defp format_phone(phone) do
    phone
    |> to_string()
    |> String.replace("+1", "")
    |> String.replace(~r/[^0-9]/, "")
    |> remove_country_code_without_plus()
    |> validate_phone()
  end

  # Sometimes phone numbers include the country code without the '+',
  # this will remove it.
  defp remove_country_code_without_plus(phone) do
    case String.length(phone) > 10 do
      true -> String.slice(phone, 1..-1//1)
      false -> phone
    end
  end

  defp sanitize(value) do
    value
    |> RemoveEmoji.sanitize()
    |> String.trim()
  end

  defp validate_phone(phone) do
    case String.length(phone) do
      10 -> {:ok, phone}
      _ -> Error.new("Phone number length is invalid", details: phone)
    end
  end
end
