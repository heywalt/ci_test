defmodule WaltUiWeb.Api.HumanLoopControllerTest do
  use WaltUiWeb.ConnCase, async: true
  use Mimic

  import WaltUi.Factory

  setup :verify_on_exit!

  setup do
    user = insert(:user)
    contact = insert(:contact, user_id: user.id)

    [contact: contact, user: user]
  end

  describe "get_text_message/2" do
    test "returns a text message from HumanLoop", %{conn: conn, contact: contact, user: user} do
      expect(WaltUi.HumanLoop.Http, :call_prompt, fn _, _, _ -> {:ok, "Hello, how are you?"} end)

      assert data =
               conn
               |> authenticate_user(user)
               |> get(~p"/api/human-loop/text-message/#{contact.id}")
               |> json_response(200)
               |> Map.get("data")

      assert data == "Hello, how are you?"
    end
  end

  test "returns an error if the contact is not found", %{conn: conn, user: user} do
    assert conn
           |> authenticate_user(user)
           |> get(~p"/api/human-loop/text-message/#{Ecto.UUID.generate()}")
           |> json_response(404) == %{"errors" => %{"detail" => "Not Found"}}
  end
end
