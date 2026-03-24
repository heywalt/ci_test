defmodule WaltUiWeb.Api.ExternalAccountsController do
  use WaltUiWeb, :controller

  require Logger

  alias WaltUi.ExternalAccounts
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  def create(conn, params) do
    current_user = conn.assigns.current_user
    params = Map.put(params, "user_id", current_user.id)

    with {:ok, external_account} <- ExternalAccounts.create_from_mobile(params) do
      conn
      |> put_view(WaltUiWeb.Api.ExternalAccountsView)
      |> render(:show, %{data: external_account})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, external_account} <- ExternalAccounts.fetch(id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, external_account),
         {:ok, _external_account} <- ExternalAccounts.delete(external_account) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(:no_content, "")
    end
  end
end
