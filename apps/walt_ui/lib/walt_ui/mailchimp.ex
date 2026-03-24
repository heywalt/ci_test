defmodule WaltUi.Mailchimp do
  @moduledoc """
  Context for interacting with the Mailchimp API.
  """
  require Logger

  alias WaltUi.Account.User

  @doc """
  Add a user to our Mailchimp list.
  """
  @spec add_user_to_list(User.t()) :: {:ok, map} | {:error, String.t()}
  def add_user_to_list(user) do
    endpoint = "/lists/#{config(:list_id)}/members"

    # Required parameters
    payload = %{
      email_address: user.email,
      status: "subscribed",
      merge_fields: %{
        FIRST_NAME: user.first_name || "",
        LAST_NAME: user.last_name || "",
        CONTACTS: length(user.contacts)
      },
      tags: ["New User"]
    }

    client()
    |> Tesla.post(endpoint, payload)
    |> handle_response()
  end

  @doc """
  Update a user's contact count in the Mailchimp list.
  """
  @spec set_contact_count(String.t(), non_neg_integer) :: {:ok, map} | {:error, String.t()}
  def set_contact_count(email, count) do
    payload = %{merge_fields: %{CONTACTS: count}}

    client()
    |> Tesla.patch("/lists/#{config(:list_id)}/members/#{hash(email)}", payload)
    |> handle_response()
  end

  defp client do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, config(:base_url)},
        {Tesla.Middleware.BearerAuth, token: config(:api_key)},
        {Tesla.Middleware.Headers, [{"Content-Type", "application/json"}]},
        Tesla.Middleware.JSON
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp config(key) do
    Application.get_env(:walt_ui, __MODULE__)[key]
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: code, body: body}}) do
    message = "Request failed with status #{code}: #{inspect(body)}"

    Logger.error(message)

    {:error, message}
  end

  defp hash(email) when is_binary(email) do
    email
    |> String.downcase()
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode16(case: :lower)
  end
end
