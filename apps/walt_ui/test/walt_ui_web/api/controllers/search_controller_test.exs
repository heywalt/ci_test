defmodule WaltUiWeb.Api.Controllers.SearchControllerTest do
  use WaltUiWeb.ConnCase
  use Mimic

  import WaltUi.Factory
  import WaltUi.SearchFixtures

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    test "returns search results for a valid search", %{conn: conn} do
      user = insert(:user)
      query = "test"

      expect(ExTypesense, :multi_search, fn _ -> search_response(user) end)

      conn =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/search?query=#{query}")

      assert length(json_response(conn, 200)["data"]) == 2
    end

    test "passes page opts to search", %{conn: conn} do
      user = insert(:user)

      expect(ExTypesense, :multi_search, fn req ->
        [contacts] = Enum.filter(req, &(&1.collection == "contacts"))

        assert contacts.page == 1
        assert contacts.per_page == "5"

        search_response(user)
      end)

      conn
      |> authenticate_user(user)
      |> get(~p"/api/search?query=test&page[number]=2&page[size]=5")
    end
  end
end
