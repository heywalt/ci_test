defmodule WaltUiWeb.Plug.RejectTraceTest do
  use WaltUiWeb.ConnCase, async: true

  alias WaltUiWeb.Plug.RejectTrace

  describe "call/2" do
    test "rejects TRACE requests with 405 Method Not Allowed", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "TRACE")
        |> RejectTrace.call([])

      assert conn.status == 405
      assert conn.halted == true
      assert conn.resp_body =~ "Method Not Allowed"
    end

    test "rejects TRACK requests with 405 Method Not Allowed", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "TRACK")
        |> RejectTrace.call([])

      assert conn.status == 405
      assert conn.halted == true
      assert conn.resp_body =~ "Method Not Allowed"
    end

    test "allows GET requests", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "GET")
        |> RejectTrace.call([])

      refute conn.halted
      assert is_nil(conn.status)
    end

    test "allows POST requests", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "POST")
        |> RejectTrace.call([])

      refute conn.halted
      assert is_nil(conn.status)
    end

    test "allows PUT requests", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "PUT")
        |> RejectTrace.call([])

      refute conn.halted
      assert is_nil(conn.status)
    end

    test "allows DELETE requests", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "DELETE")
        |> RejectTrace.call([])

      refute conn.halted
      assert is_nil(conn.status)
    end

    test "allows OPTIONS requests (needed for CORS)", %{conn: conn} do
      conn =
        conn
        |> Map.put(:method, "OPTIONS")
        |> RejectTrace.call([])

      refute conn.halted
      assert is_nil(conn.status)
    end
  end
end
