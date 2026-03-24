defmodule WaltUiWeb.Api.Contacts.AddressControllerTest do
  use WaltUiWeb.ConnCase

  import AssertAsync
  import WaltUi.Factory

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json"), user: insert(:user)}
  end

  describe "GET /api/contacts/:contact_id/addresses" do
    test "returns an empty list", ctx do
      contact = insert(:contact, user_id: ctx.user.id)

      conn =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> get(~p"/api/contacts/#{contact.id}/addresses")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns a list of possible addresses", ctx do
      contact = insert(:contact, enrichment_id: Ecto.UUID.generate(), user_id: ctx.user.id)
      addr_1 = insert(:possible_address, enrichment_id: contact.enrichment_id)
      addr_2 = insert(:possible_address, enrichment_id: contact.enrichment_id)

      conn =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> get(~p"/api/contacts/#{contact.id}/addresses")

      assert %{"data" => addresses} = json_response(conn, 200)

      # PossibleAddress ID included in payload
      assert addr_1.id in Enum.map(addresses, &Map.get(&1, "id"))
      assert addr_2.id in Enum.map(addresses, &Map.get(&1, "id"))

      # Address details included in payload
      assert addr_1.street_1 in Enum.map(addresses, &Map.get(&1, "street_1"))
      assert addr_2.zip in Enum.map(addresses, &Map.get(&1, "zip"))

      # Enrichment ID and timestamps not included in payload
      refute Enum.any?(addresses, &is_map_key(&1, "enrichment_id"))
      refute Enum.any?(addresses, &is_map_key(&1, "inserted_at"))
      refute Enum.any?(addresses, &is_map_key(&1, "updated_at"))
    end
  end

  describe "PUT /api/contacts/:contact_id/addresses" do
    test "updates contact address with existing possible address", ctx do
      contact = WaltUi.Helpers.await_contact(user_id: ctx.user.id)
      enrichment_id = Ecto.UUID.generate()
      CQRS.update_contact(contact, %{enrichment_id: enrichment_id})

      addr_1 =
        insert(:possible_address,
          enrichment_id: enrichment_id,
          street_1: "123 Main St",
          city: "Testville"
        )

      ctx.conn
      |> authenticate_user(ctx.user)
      |> put(~p"/api/contacts/#{contact.id}/addresses", %{id: addr_1.id})
      |> response(204)

      assert_async do
        assert %{street_1: "123 Main St", city: "Testville"} = Repo.reload(contact)
      end
    end
  end

  describe "POST /api/contacts/:contact_id/addresses" do
    test "updates contact address with new address", ctx do
      contact = WaltUi.Helpers.await_contact(user_id: ctx.user.id)
      enrichment_id = Ecto.UUID.generate()
      CQRS.update_contact(contact, %{enrichment_id: enrichment_id})

      params = %{
        street_1: "456 Broad St",
        street_2: "#42",
        city: "Testington",
        state: "CA",
        zip: "11111"
      }

      ctx.conn
      |> authenticate_user(ctx.user)
      |> post(~p"/api/contacts/#{contact.id}/addresses", params)
      |> response(204)

      assert_async do
        assert %{
                 street_1: "456 Broad St",
                 street_2: "#42",
                 city: "Testington",
                 state: "CA",
                 zip: "11111"
               } = Repo.reload(contact)
      end
    end

    test "street_2 field is optional", ctx do
      contact = WaltUi.Helpers.await_contact(user_id: ctx.user.id)
      enrichment_id = Ecto.UUID.generate()
      CQRS.update_contact(contact, %{enrichment_id: enrichment_id})

      params = %{
        street_1: "1 Central Ave",
        city: "Foo City",
        state: "VA",
        zip: "55555"
      }

      ctx.conn
      |> authenticate_user(ctx.user)
      |> post(~p"/api/contacts/#{contact.id}/addresses", params)
      |> response(204)

      assert_async do
        assert %{street_1: "1 Central Ave", street_2: nil} = Repo.reload(contact)
      end
    end
  end
end
