defmodule WaltUiWeb.Plug.EnsureContentTypeTest do
  use WaltUiWeb.ConnCase, async: true

  import Phoenix.Controller, only: [redirect: 2]

  alias WaltUiWeb.Plug.EnsureContentType

  describe "call/2" do
    test "sets default Content-Type when missing on normal response", %{conn: conn} do
      conn =
        conn
        |> EnsureContentType.call([])
        |> send_resp(200, "OK")

      content_type = get_resp_header(conn, "content-type")
      assert length(content_type) > 0
      assert List.first(content_type) =~ "text/html"
    end

    test "does not override existing Content-Type", %{conn: conn} do
      conn =
        conn
        |> put_resp_header("content-type", "application/json")
        |> EnsureContentType.call([])
        |> send_resp(200, ~s({"status":"ok"}))

      assert get_resp_header(conn, "content-type") == ["application/json"]
    end

    test "sets Content-Type on redirect responses", %{conn: conn} do
      conn =
        conn
        |> EnsureContentType.call([])
        |> redirect(to: "/dashboard")

      content_type = get_resp_header(conn, "content-type")
      assert length(content_type) > 0
      assert List.first(content_type) =~ "text/html"
    end

    test "works with JSON responses", %{conn: conn} do
      conn =
        conn
        |> put_resp_content_type("application/json")
        |> EnsureContentType.call([])
        |> send_resp(200, ~s({"status":"ok"}))

      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
    end
  end
end
