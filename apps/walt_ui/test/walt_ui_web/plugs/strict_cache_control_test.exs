defmodule WaltUiWeb.Plug.StrictCacheControlTest do
  use WaltUiWeb.ConnCase, async: true

  alias WaltUiWeb.Plug.StrictCacheControl

  describe "call/2" do
    test "sets Cache-Control with no-cache, no-store, must-revalidate, private", %{conn: conn} do
      conn =
        conn
        |> StrictCacheControl.call([])
        |> send_resp(200, "OK")

      cache_control = get_resp_header(conn, "cache-control") |> List.first()

      assert cache_control =~ "no-cache"
      assert cache_control =~ "no-store"
      assert cache_control =~ "must-revalidate"
      assert cache_control =~ "private"
    end

    test "sets Pragma: no-cache for HTTP 1.0 compatibility", %{conn: conn} do
      conn =
        conn
        |> StrictCacheControl.call([])
        |> send_resp(200, "OK")

      assert get_resp_header(conn, "pragma") == ["no-cache"]
    end

    test "sets Expires: 0 for HTTP 1.0 compatibility", %{conn: conn} do
      conn =
        conn
        |> StrictCacheControl.call([])
        |> send_resp(200, "OK")

      assert get_resp_header(conn, "expires") == ["0"]
    end

    test "overrides existing Cache-Control header", %{conn: conn} do
      conn =
        conn
        |> put_resp_header("cache-control", "public, max-age=3600")
        |> StrictCacheControl.call([])
        |> send_resp(200, "OK")

      cache_control = get_resp_header(conn, "cache-control") |> List.first()

      # Should override with strict settings
      refute cache_control =~ "public"
      refute cache_control =~ "max-age=3600"
      assert cache_control =~ "no-cache"
      assert cache_control =~ "no-store"
    end

    test "works with JSON responses", %{conn: conn} do
      conn =
        conn
        |> put_resp_content_type("application/json")
        |> StrictCacheControl.call([])
        |> send_resp(200, ~s({"data":"sensitive"}))

      cache_control = get_resp_header(conn, "cache-control") |> List.first()
      assert cache_control =~ "no-store"
    end

    test "all three headers are set together", %{conn: conn} do
      conn =
        conn
        |> StrictCacheControl.call([])
        |> send_resp(200, "OK")

      # All three headers should be present
      assert length(get_resp_header(conn, "cache-control")) == 1
      assert length(get_resp_header(conn, "pragma")) == 1
      assert length(get_resp_header(conn, "expires")) == 1
    end
  end
end
