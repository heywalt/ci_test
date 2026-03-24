defmodule WaltUiWeb.Api.Controllers.ImageControllerTest do
  use WaltUiWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "GCS upload" do
    test "fails when unauthorized", %{conn: conn} do
      conn = get(conn, ~p"/api/upload/contacts/jpeg")

      assert json_response(conn, 401)["data"] == nil
    end
  end
end
