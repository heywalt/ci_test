defmodule WaltUiWeb.Api.UsersController do
  use WaltUiWeb, :controller

  action_fallback WaltUiWeb.FallbackController

  def show(conn, _params) do
    current_user = conn.assigns.current_user

    conn
    |> put_view(WaltUiWeb.Api.UsersView)
    |> render("show.json", %{data: current_user})
  end

  def update(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, user} <- WaltUi.Account.update_user(current_user, params) do
      conn
      |> put_view(WaltUiWeb.Api.UsersView)
      |> render("show.json", %{data: user})
    end
  end

  @spec delete(any(), any()) :: {:error, Ecto.Changeset.t()} | Plug.Conn.t()
  def delete(conn, _params) do
    current_user = conn.assigns.current_user

    with {:ok, _user} <- WaltUi.Account.delete_user(current_user) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(:no_content, "")
    end
  end
end
