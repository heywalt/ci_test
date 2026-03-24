defmodule WaltUi.Notifications.Fcm.Client do
  @moduledoc """
  Client for sending Firebase Cloud Messaging notifications.
  """
  require Logger

  alias WaltUi.Account
  alias WaltUi.Notifications
  alias WaltUi.Notifications.Fcm.Http

  @doc """
  Sends a notification to all of a user's registered devices.

  Returns `{:ok, count}` where count is the number of successful sends.
  Automatically removes defunct tokens (404/410 responses from FCM).
  """
  @spec send_notification(String.t(), String.t(), String.t(), map()) :: {:ok, non_neg_integer()}
  def send_notification(user_id, title, body, data \\ %{}) do
    user = Account.get_user(user_id)

    tokens = Notifications.get_user_tokens(user)

    payload = %{
      title: title,
      body: body,
      data: data
    }

    results =
      Enum.map(tokens, fn fcm_token ->
        result = Http.send_notification(fcm_token.token, payload)

        case result do
          {:error, reason} when reason in [:not_found, :gone] ->
            Repo.delete(fcm_token)
            {:error, :defunct}

          other ->
            other
        end
      end)

    successful_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)
    defunct_count = Enum.count(results, fn result -> result == {:error, :defunct} end)

    if defunct_count > 0 do
      Logger.info("Removed #{defunct_count} defunct FCM token(s) for user #{user_id}")
    end

    Logger.info("Sent #{successful_count} FCM notification(s) to user #{user_id}")

    {:ok, successful_count}
  end

  @doc """
  Sends a notification to a specific FCM token.

  Returns `{:ok, response}` on success or `{:error, reason}` on failure.
  Does not automatically remove tokens - use `send_notification/4` for that behavior.
  """
  @spec send_notification_to_token(String.t(), String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, atom()}
  def send_notification_to_token(token, title, body, data \\ %{}) do
    payload = %{
      title: title,
      body: body,
      data: data
    }

    Http.send_notification(token, payload)
  end
end
