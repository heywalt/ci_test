defmodule WaltUiWeb.AuthLiveAssigns do
  @moduledoc """
  Ensures common `assigns` are applied to all LiveViews attaching this hook.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:default, _params, session, socket) do
    case get_current_user_from_session(session) do
      {:ok, user} ->
        Logger.metadata(user_id: user.id)
        {:cont, assign(socket, :current_user, user)}

      {:error, _reason} ->
        {:halt, redirect(socket, to: "/auth/auth0")}
    end
  end

  defp get_current_user_from_session(%{"session_id" => session_id}) when not is_nil(session_id) do
    case WaltUi.Account.get_session(session_id) do
      {:ok, session} ->
        user = Repo.re_preload(session.user, [:external_accounts])
        {:ok, user}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_current_user_from_session(_session) do
    {:error, :no_session}
  end
end
