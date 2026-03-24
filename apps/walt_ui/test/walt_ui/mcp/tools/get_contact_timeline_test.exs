defmodule WaltUi.MCP.Tools.GetContactTimelineTest do
  use WaltUi.CqrsCase

  import WaltUi.Factory

  alias WaltUi.MCP.Tools.GetContactTimeline
  alias WaltUi.Projections.ContactInteraction

  describe "execute/2" do
    setup do
      user = insert(:user)
      contact = await_contact(user_id: user.id, email: "john.connor@skynet.com")

      [user: user, contact: contact]
    end

    test "returns timeline for valid contact_id", %{user: user, contact: contact} do
      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_id" => contact.id}

      assert {:ok, %{"timeline" => timeline}} = GetContactTimeline.execute(params, frame)
      assert is_list(timeline)

      # Contact creation should be in timeline (created by await_contact)
      assert Enum.any?(timeline, fn item -> item["type"] == "contact_created" end)
    end

    test "returns error when user_id missing from frame", %{contact: contact} do
      frame = %{assigns: %{}}
      params = %{"contact_id" => contact.id}

      assert {:error, "user_id is required in context"} =
               GetContactTimeline.execute(params, frame)
    end

    test "returns error when contact not found", %{user: user} do
      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_id" => Ecto.UUID.generate()}

      assert {:error, "Contact not found or not authorized"} =
               GetContactTimeline.execute(params, frame)
    end

    test "returns error when contact belongs to different user", %{contact: contact} do
      other_user = insert(:user)
      frame = %{assigns: %{user_id: other_user.id}}
      params = %{"contact_id" => contact.id}

      assert {:error, "Contact not found or not authorized"} =
               GetContactTimeline.execute(params, frame)
    end

    test "filters by activity_type when provided", %{user: user, contact: contact} do
      # Insert a corresponded interaction
      Repo.insert!(%ContactInteraction{
        activity_type: :contact_corresponded,
        contact_id: contact.id,
        occurred_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        metadata: %{
          "direction" => "outbound",
          "subject" => "Re: Terminator plans",
          "from" => "user@example.com",
          "to" => "john.connor@skynet.com"
        }
      })

      frame = %{assigns: %{user_id: user.id}}

      # Filter for only emails
      params = %{"contact_id" => contact.id, "activity_type" => "contact_corresponded"}
      assert {:ok, %{"timeline" => timeline}} = GetContactTimeline.execute(params, frame)

      assert Enum.all?(timeline, fn item -> item["type"] == "email" end)
      assert length(timeline) == 1
    end

    test "returns error for invalid activity_type", %{user: user, contact: contact} do
      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_id" => contact.id, "activity_type" => "invalid_type"}

      assert {:error, message} = GetContactTimeline.execute(params, frame)
      assert message =~ "Invalid activity_type"
    end

    test "respects limit parameter", %{user: user, contact: contact} do
      # Insert multiple interactions
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      for i <- 1..5 do
        Repo.insert!(%ContactInteraction{
          activity_type: :contact_corresponded,
          contact_id: contact.id,
          occurred_at: NaiveDateTime.add(now, -i, :day),
          metadata: %{"direction" => "inbound", "subject" => "Email #{i}"}
        })
      end

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_id" => contact.id, "limit" => 3}

      assert {:ok, %{"timeline" => timeline}} = GetContactTimeline.execute(params, frame)
      assert length(timeline) == 3
    end

    test "formats meeting interactions correctly", %{user: user, contact: contact} do
      Repo.insert!(%ContactInteraction{
        activity_type: :contact_invited,
        contact_id: contact.id,
        occurred_at: ~N[2024-12-05 14:00:00],
        metadata: %{
          "name" => "Strategy Meeting",
          "start_time" => "2024-12-05T14:00:00Z",
          "end_time" => "2024-12-05T15:00:00Z",
          "location" => "Zoom",
          "link" => "https://zoom.us/j/123456",
          "status" => "accepted"
        }
      })

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_id" => contact.id, "activity_type" => "contact_invited"}

      assert {:ok, %{"timeline" => [meeting]}} = GetContactTimeline.execute(params, frame)

      assert meeting["type"] == "meeting"
      assert meeting["description"] == "Meeting: Strategy Meeting"
      assert meeting["meeting_name"] == "Strategy Meeting"
      assert meeting["location"] == "Zoom"
      assert meeting["link"] == "https://zoom.us/j/123456"
    end

    test "formats email interactions correctly", %{user: user, contact: contact} do
      Repo.insert!(%ContactInteraction{
        activity_type: :contact_corresponded,
        contact_id: contact.id,
        occurred_at: ~N[2024-12-05 10:00:00],
        metadata: %{
          "direction" => "inbound",
          "subject" => "Important update",
          "from" => "john.connor@skynet.com",
          "to" => "user@example.com",
          "message_link" => "https://mail.google.com/mail/u/0/#inbox/abc123"
        }
      })

      frame = %{assigns: %{user_id: user.id}}
      params = %{"contact_id" => contact.id, "activity_type" => "contact_corresponded"}

      assert {:ok, %{"timeline" => [email]}} = GetContactTimeline.execute(params, frame)

      assert email["type"] == "email"
      assert email["description"] == "Email received: Important update"
      assert email["direction"] == "inbound"
      assert email["subject"] == "Important update"
      assert email["message_link"] == "https://mail.google.com/mail/u/0/#inbox/abc123"
    end
  end
end
