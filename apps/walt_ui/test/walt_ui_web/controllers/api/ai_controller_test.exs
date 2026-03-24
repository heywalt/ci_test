defmodule WaltUiWeb.Api.Controllers.AIControllerTest do
  use WaltUiWeb.ConnCase
  use Mimic

  import WaltUi.Factory
  import WaltUi.Helpers

  alias WaltUi.Google.VertexAI.Client

  setup :verify_on_exit!

  setup ctx do
    user = insert(:user)
    conn = put_req_header(ctx.conn, "accept", "application/json")

    [conn: conn, user: user]
  end

  describe "POST /api/ai/query with contact_id" do
    test "accepts valid contact_id that belongs to user and prepends contact context", ctx do
      contact = await_contact(user_id: ctx.user.id)

      expect(Client, :query, fn _prompt, user_id, opts ->
        assert user_id == ctx.user.id

        # Verify contact context was prepended to conversation history
        history = Keyword.get(opts, :conversation_history, [])
        assert length(history) == 1

        context_message = List.first(history)
        assert context_message["role"] == "user"
        context_text = context_message["parts"] |> List.first() |> Map.get("text")
        assert context_text =~ "You are currently viewing details for the following contact"
        assert context_text =~ contact.first_name
        assert context_text =~ contact.id

        {:ok, "The contact's Move score is high because...",
         %{"promptTokenCount" => 100, "candidatesTokenCount" => 50}}
      end)

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> post(~p"/api/ai/query", %{
          "prompt" => "Why is their Move score so high?",
          "new_conversation" => true,
          "contact_id" => contact.id
        })

      assert json_response(result, 200)
    end

    test "rejects contact_id that doesn't belong to user", ctx do
      other_user = insert(:user)
      other_contact = await_contact(user_id: other_user.id)

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> post(~p"/api/ai/query", %{
          "prompt" => "Why is their Move score so high?",
          "new_conversation" => true,
          "contact_id" => other_contact.id
        })

      assert json_response(result, 404) == %{
               "error" => "Contact not found"
             }
    end

    test "rejects invalid contact_id", ctx do
      invalid_contact_id = Ecto.UUID.generate()

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> post(~p"/api/ai/query", %{
          "prompt" => "Why is their Move score so high?",
          "new_conversation" => true,
          "contact_id" => invalid_contact_id
        })

      assert json_response(result, 404) == %{
               "error" => "Contact not found"
             }
    end

    test "works without contact_id for backward compatibility", ctx do
      expect(Client, :query, fn _prompt, user_id, opts ->
        assert user_id == ctx.user.id

        # Verify no contact context was added
        history = Keyword.get(opts, :conversation_history, [])
        assert history == []

        {:ok, "Move score is calculated based on...",
         %{"promptTokenCount" => 100, "candidatesTokenCount" => 50}}
      end)

      result =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> post(~p"/api/ai/query", %{
          "prompt" => "How does Move score work?",
          "new_conversation" => true
        })

      assert json_response(result, 200)
    end
  end
end
