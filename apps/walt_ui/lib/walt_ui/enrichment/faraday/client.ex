defmodule WaltUi.Enrichment.Faraday.Client do
  @moduledoc """
  Context for interacting with Faraday.
  """
  alias WaltUi.Directory
  alias WaltUi.Enrichment.Faraday.Http
  alias WaltUi.Projections.Contact
  alias WaltUi.Providers.Endato

  def fetch_by_identity_sets(id_sets) do
    Http.fetch_contact(%{identity_sets: id_sets})
  end

  def fetch_contact(contact) do
    case format_contact_request(contact) do
      {:ok, request} ->
        Http.fetch_contact(request)

      {:error, contact} ->
        {:error, contact}
    end
  end

  def extract_ptt(response) do
    case Map.get(
           response,
           "fdy_outcome_2cac2e5e_27d4_4045_99ef_0338f007b8e6_propensity_probability"
         ) do
      nil -> {:error, :no_ptt}
      ptt -> {:ok, ptt}
    end
  end

  defp format_contact_request(data) do
    with {:ok, person} <- format_person(data),
         {:ok, address} <- format_address(data) do
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

  defp format_person(data) do
    person = %{
      person_first_name: sanitize(data.first_name),
      person_last_name: sanitize(data.last_name),
      email: data.email,
      phone: format_phone(data.phone)
    }

    person
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.into(%{})
    |> then(&{:ok, &1})
  end

  defp format_address(%Endato{} = data) do
    {:ok,
     %{
       house_number_and_street: String.trim("#{data.street_1} #{data.street_2}"),
       city: data.city,
       state: data.state,
       postcode: data.zip
     }}
  end

  defp format_address(%{street_1: nil}), do: {:ok, %{}}

  defp format_address(%Contact{} = contact) do
    {:ok,
     %{
       house_number_and_street: Directory.house_number_and_street(contact),
       city: contact.city,
       state: contact.state,
       postcode: contact.zip
     }}
  end

  defp format_phone(phone) do
    phone
    |> to_string()
    |> String.replace("+1", "")
    |> String.replace(~r/[^0-9]/, "")
  end

  defp sanitize(value) do
    value
    |> RemoveEmoji.sanitize()
    |> String.trim()
  end
end
