defmodule WaltUiWeb.Plug.StoreReturnPath do
  @moduledoc """
  Stores the current request path in the session for redirect after login.
  Only stores paths for authenticated routes (not auth routes).
  """
  import Plug.Conn

  @auth_paths ["/auth", "/login", "/logout"]

  def init(opts), do: opts

  def call(conn, _opts) do
    if should_store_path?(conn.request_path) do
      put_session(conn, :return_to, conn.request_path)
    else
      conn
    end
  end

  defp should_store_path?(path) do
    not Enum.any?(@auth_paths, &String.starts_with?(path, &1))
  end
end
