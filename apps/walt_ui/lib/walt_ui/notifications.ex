defmodule WaltUi.Notifications do
  @moduledoc """
  The Notifications context for managing FCM tokens and push notifications.
  """
  import Ecto.Query, warn: false

  alias WaltUi.Account.User
  alias WaltUi.Notifications.FcmToken

  @doc """
  Registers a device FCM token for a user. Uses find_or_create pattern to handle
  duplicate token registration idempotently.
  """
  @spec register_device(User.t(), String.t()) ::
          {:ok, FcmToken.t()} | {:error, Ecto.Changeset.t()}
  def register_device(%User{} = user, token) when is_binary(token) do
    case Repo.get_by(FcmToken, token: token) do
      %FcmToken{} = existing_token ->
        {:ok, existing_token}

      nil ->
        %FcmToken{}
        |> FcmToken.changeset(%{token: token, user_id: user.id})
        |> Repo.insert()
    end
  end

  def register_device(%User{}, _token) do
    {:error, FcmToken.changeset(%FcmToken{}, %{})}
  end

  @doc """
  Updates an FCM token. Checks authorization to ensure the token belongs to the user.
  """
  @spec update_device_token(String.t(), User.t(), String.t()) ::
          {:ok, FcmToken.t()} | {:error, :not_found | :unauthorized | Ecto.Changeset.t()}
  def update_device_token(token_id, %User{} = user, new_token) do
    case Repo.get(FcmToken, token_id) do
      nil ->
        {:error, :not_found}

      %FcmToken{user_id: user_id} = fcm_token when user_id == user.id ->
        fcm_token
        |> FcmToken.changeset(%{token: new_token})
        |> Repo.update()

      %FcmToken{} ->
        {:error, :unauthorized}
    end
  end

  @doc """
  Unregisters (deletes) an FCM token. Checks authorization to ensure the token belongs to the user.
  """
  @spec unregister_device(String.t(), User.t()) ::
          {:ok, FcmToken.t()} | {:error, :not_found | :unauthorized}
  def unregister_device(token_id, %User{} = user) do
    case Repo.get(FcmToken, token_id) do
      nil ->
        {:error, :not_found}

      %FcmToken{user_id: user_id} = fcm_token when user_id == user.id ->
        Repo.delete(fcm_token)

      %FcmToken{} ->
        {:error, :unauthorized}
    end
  end

  @doc """
  Returns all FCM tokens for a user.
  """
  @spec get_user_tokens(User.t()) :: [FcmToken.t()]
  def get_user_tokens(%User{} = user) do
    q = from(t in FcmToken, where: t.user_id == ^user.id)
    Repo.all(q)
  end
end
