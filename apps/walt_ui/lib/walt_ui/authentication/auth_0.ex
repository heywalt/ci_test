defmodule WaltUi.Authentication.Auth0 do
  @moduledoc """
  Module for interacting with Auth0 API.
  """

  alias WaltUi.Authentication.Auth0.Http

  @spec fetch_user(String.t()) :: {:ok, map()} | {:error, atom()}
  def fetch_user(auth0_user_id) do
    Http.fetch_user(auth0_user_id)
  end

  @spec fetch_user_access_token(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def fetch_user_access_token(auth0_user_id) do
    case fetch_user(auth0_user_id) do
      {:ok, user} ->
        idp_access_token = List.first(user["identities"])["access_token"]

        {:ok, idp_access_token}

      {:error, error} ->
        {:error, error}
    end
  end

  @spec user_attrs_from_mobile_token(String.t()) :: {:ok, map()} | {:error, String.t()}
  def user_attrs_from_mobile_token(mobile_id_token) do
    case verify_jwt(mobile_id_token) do
      {:ok, token_map} ->
        {:ok,
         %{
           email: Map.get(token_map, "email"),
           first_name: Map.get(token_map, "given_name"),
           last_name: Map.get(token_map, "family_name"),
           avatar: Map.get(token_map, "picture")
         }}

      _error ->
        {:error, "Invalid token"}
    end
  end

  @spec jwt_expired?(map | String.t()) :: boolean()
  def jwt_expired?(token) do
    jwt_expired?(token, DateTime.utc_now())
  end

  @spec jwt_expired?(map | String.t(), DateTime.t()) :: boolean()
  def jwt_expired?(%{"exp" => expires}, expiration) do
    DateTime.compare(DateTime.from_unix!(expires), expiration) == :lt
  end

  def jwt_expired?(jwt, expiration) when is_binary(jwt) do
    case verify_jwt(jwt) do
      {:ok, token} ->
        jwt_expired?(token, expiration)

      _ ->
        true
    end
  end

  defp verify_jwt(token) do
    Joken.Signer.verify(token, Joken.Signer.parse_config(:rs256))
  end
end
