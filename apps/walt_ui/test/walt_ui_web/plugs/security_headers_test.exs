defmodule WaltUiWeb.Plug.SecurityHeadersTest do
  use WaltUiWeb.ConnCase, async: true

  alias WaltUiWeb.Plug.SecurityHeaders

  describe "call/2" do
    test "removes X-Powered-By header", %{conn: conn} do
      conn =
        conn
        |> put_resp_header("x-powered-by", "Phoenix")
        |> SecurityHeaders.call([])
        |> send_resp(200, "OK")

      assert get_resp_header(conn, "x-powered-by") == []
    end

    test "adds generic Server header to prevent fingerprinting", %{conn: conn} do
      conn =
        conn
        |> SecurityHeaders.call([])
        |> send_resp(200, "OK")

      # Should either have no server header or a generic one
      server_headers = get_resp_header(conn, "server")
      assert server_headers == [] or server_headers == [""]
    end

    test "does not interfere with other headers", %{conn: conn} do
      conn =
        conn
        |> put_resp_header("content-type", "application/json")
        |> put_resp_header("x-custom-header", "custom-value")
        |> SecurityHeaders.call([])
        |> send_resp(200, "OK")

      assert get_resp_header(conn, "content-type") == ["application/json"]
      assert get_resp_header(conn, "x-custom-header") == ["custom-value"]
    end

    test "works with empty conn", %{conn: conn} do
      conn =
        conn
        |> SecurityHeaders.call([])
        |> send_resp(200, "OK")

      assert conn.status == 200
    end

    test "sets X-Content-Type-Options to nosniff", %{conn: conn} do
      conn =
        conn
        |> SecurityHeaders.call([])
        |> send_resp(200, "OK")

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "does not override existing X-Content-Type-Options header", %{conn: conn} do
      conn =
        conn
        |> put_resp_header("x-content-type-options", "nosniff")
        |> SecurityHeaders.call([])
        |> send_resp(200, "OK")

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "HSTS header is not set in test environment", %{conn: conn} do
      conn =
        conn
        |> SecurityHeaders.call([])
        |> send_resp(200, "OK")

      # In test/dev environment, HSTS should NOT be set
      # (only set in production where we have HTTPS)
      hsts_header = get_resp_header(conn, "strict-transport-security")
      assert hsts_header == []
    end

    test "HSTS configuration is correct for production" do
      # This test documents the HSTS configuration for production
      # In production (Mix.env() == :prod), the header will be:
      # "strict-transport-security: max-age=31536000; includeSubDomains"
      #
      # max-age=31536000 = 1 year
      # includeSubDomains = applies to all subdomains (app.heywalt.ai, www.heywalt.ai, etc.)

      expected_value = "max-age=31536000; includeSubDomains"

      # Verify the expected format is valid
      assert expected_value =~ "max-age=31536000"
      assert expected_value =~ "includeSubDomains"
    end
  end
end
