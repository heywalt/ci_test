defmodule WaltUiWeb.Plug.HealthCheck do
  @moduledoc """
  Plug for the `/api/health-check` route. Halts before the request can continue, so it will not be logged.
  """
  import Plug.Conn

  alias Ecto.Adapters.SQL

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{request_path: "/api/health-check"} = conn, _) do
    if db?() do
      conn
      |> send_resp(200, "ok")
      |> halt()
    else
      conn
      |> send_resp(503, "Service Unavailable")
      |> halt()
    end
  end

  def call(conn, _opts), do: conn

  defp db? do
    case SQL.query(Repo, "SELECT true", []) do
      {:ok, _} -> true
      _else -> false
    end
  end
end
