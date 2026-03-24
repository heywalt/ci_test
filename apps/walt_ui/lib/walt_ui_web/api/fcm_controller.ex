defmodule WaltUiWeb.Api.FcmController do
  use WaltUiWeb, :controller

  alias WaltUi.Notifications

  action_fallback WaltUiWeb.FallbackController

  def create(conn, %{"token" => token}) do
    current_user = conn.assigns.current_user

    with {:ok, _fcm_token} <- Notifications.register_device(current_user, token) do
      conn
      |> put_status(:created)
      |> json(%{status: "registered"})
    end
  end

  def create(_conn, _params) do
    {:error, :bad_request}
  end

  def update(conn, %{"id" => id, "token" => new_token}) do
    current_user = conn.assigns.current_user

    with {:ok, _fcm_token} <- Notifications.update_device_token(id, current_user, new_token) do
      json(conn, %{status: "updated"})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, _fcm_token} <- Notifications.unregister_device(id, current_user) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(:no_content, "")
    end
  end
end
