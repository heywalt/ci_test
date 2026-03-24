defmodule WaltUiWeb.Api.Controllers.ContactInteractionsControllerTest do
  use WaltUiWeb.ConnCase

  import WaltUi.Factory

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "GET /api/contact-interactions/:contact_id" do
    setup do
      [user: insert(:user)]
    end

    test "returns a list of contact interactions for the given contact",
         %{user: %{id: user_id}} = ctx do
      %{id: contact_id} = await_contact(user_id: user_id, email: "wade@deadpool.com")

      assert %{
               "data" => [
                 %{
                   "contact_id" => ^contact_id,
                   "activity_type" => "contact_created"
                 }
               ]
             } =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/contact-interactions/#{contact_id}")
               |> json_response(200)
    end

    test "returns 404 if contact is not found", ctx do
      contact_id = Ecto.UUID.generate()

      assert ctx.conn
             |> authenticate_user(ctx.user)
             |> get(~p"/api/contact-interactions/#{contact_id}")
             |> json_response(404)
    end
  end
end
