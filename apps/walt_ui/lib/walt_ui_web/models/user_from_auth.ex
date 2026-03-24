defmodule WaltUiWeb.Models.UserFromAuth do
  @moduledoc """
  Retrieve the user information from an auth request
  """
  require Logger
  require Poison

  alias Ueberauth.Auth
  alias WaltUi.Account
  alias WaltUi.Account.User

  def find_or_create(%Auth{provider: :identity} = auth) do
    case validate_pass(auth.credentials) do
      :ok ->
        auth
        |> basic_info()
        |> Account.find_or_create_user_by_oauth_user()

      {:error, reason} ->
        {:error, reason}
    end
  end

  def find_or_create(%Auth{} = auth) do
    auth
    |> basic_info()
    |> Account.find_or_create_user_by_oauth_user()
  end

  def find_or_create(%User{} = user) do
    {:ok, user}
  end

  # github does it this way
  defp avatar_from_auth(%{info: %{urls: %{avatar_url: image}}}), do: image

  # facebook does it this way
  defp avatar_from_auth(%{info: %{image: image}}), do: image

  # default case if nothing matches
  defp avatar_from_auth(auth) do
    Logger.warning(auth.provider <> " needs to find an avatar URL!")
    Logger.debug(Poison.encode!(auth))
    nil
  end

  defp email_from_auth(%{info: %{email: email}}), do: email

  defp basic_info(auth) do
    %{
      auth_uid: auth.uid,
      first_name: first_name_from_auth(auth),
      last_name: last_name_from_auth(auth),
      email: email_from_auth(auth),
      avatar: avatar_from_auth(auth)
    }
  end

  defp first_name_from_auth(%{info: %{first_name: first_name}}), do: first_name

  defp last_name_from_auth(%{info: %{last_name: last_name}}), do: last_name

  defp validate_pass(%{other: %{password: ""}}) do
    {:error, "Password required"}
  end

  defp validate_pass(%{other: %{password: pw, password_confirmation: pw}}) do
    :ok
  end

  defp validate_pass(%{other: %{password: _}}) do
    {:error, "Passwords do not match"}
  end

  defp validate_pass(_), do: {:error, "Password Required"}
end
