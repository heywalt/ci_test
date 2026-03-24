defmodule WaltUi.SearchTest do
  use Repo.DataCase, async: true
  use Mimic

  import WaltUi.Factory
  import WaltUi.SearchFixtures

  alias WaltUi.Search

  setup do
    user = insert(:user, email: "test_search_#{System.unique_integer()}@example.com")
    {:ok, %{user: user}}
  end

  describe "format_search_results/1" do
    test "returns a list of contacts with search highlights", %{user: user} do
      {:ok, %{results: results}} = search_response(user)

      merged = Search.format_search_results(results)

      assert Map.get(List.first(merged), :search) != nil
    end
  end

  describe "search_all_by_user/2" do
    test "returns error" do
      expect(ExTypesense, :multi_search, fn _ -> {:error, "some error"} end)

      assert {:error, "some error"} =
               Search.search_all_by_user(Ecto.UUID.generate(), "test search")
    end

    test "returns formatted data", %{user: user} do
      expect(ExTypesense, :multi_search, fn _ -> search_response(user) end)

      assert user.id
             |> Search.search_all_by_user("test search")
             |> List.first()
             |> Map.get(:search)
    end

    test "queries with default page opts", %{user: user} do
      expect(ExTypesense, :multi_search, fn req ->
        [contacts] = Enum.filter(req, &(&1.collection == "contacts"))

        assert contacts.page == 1
        assert contacts.per_page == 30

        search_response(user)
      end)

      Search.search_all_by_user(user.id, "test")
    end

    test "queries with given page opts", %{user: user} do
      expect(ExTypesense, :multi_search, fn req ->
        [notes] = Enum.filter(req, &(&1.collection == "notes"))

        assert notes.page == 2
        assert notes.per_page == 5

        search_response(user)
      end)

      Search.search_all_by_user(user.id, "test", page: 2, per_page: 5)
    end
  end

  describe "build_filter_by/1" do
    test "returns a correctly formatted filter string for one attribute", %{user: user} do
      user_id = user.id

      opts = [
        filter_by: [%{field: "city", value: "San Francisco"}]
      ]

      match_string = "user_id: #{user_id} && city: San Francisco"
      assert ^match_string = Search.build_filter_by(user_id, opts)
    end

    test "returns a correctly formatted filter string for multiple attributes", %{user: user} do
      user_id = user.id

      opts = [
        filter_by: [%{field: "city", value: "San Francisco"}, %{field: "state", value: "CA"}]
      ]

      match_string = "user_id: #{user_id} && city: San Francisco && state: CA"
      assert ^match_string = Search.build_filter_by(user_id, opts)
    end

    test "returns a correctly formatted filter string for no attributes", %{user: user} do
      user_id = user.id

      opts = []

      match_string = "user_id: #{user_id}"
      assert ^match_string = Search.build_filter_by(user_id, opts)
    end
  end

  describe "build_order_by/1" do
    test "returns a correctly formatted order by string" do
      opts = [order_by: [%{field: "city", direction: "asc"}]]

      match_string = "city:asc"
      assert ^match_string = Search.build_order_by(opts)
    end

    test "returns a correctly formatted order by string with multiple attributes" do
      opts = [
        order_by: [%{field: "city", direction: "asc"}, %{field: "last_name", direction: "desc"}]
      ]

      match_string = "city:asc,last_name:desc"
      assert ^match_string = Search.build_order_by(opts)
    end

    test "returns a correctly formatted order by string for no attributes" do
      opts = []

      match_string = "ptt:desc"
      assert ^match_string = Search.build_order_by(opts)
    end
  end
end
