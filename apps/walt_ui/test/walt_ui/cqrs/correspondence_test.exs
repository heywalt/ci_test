defmodule WaltUi.CQRS.CorrespondenceTest do
  use WaltUi.CqrsCase
  import WaltUi.Factory

  alias CQRS.Leads.Events.ContactCorresponded

  setup do
    user = insert(:user)
    [user: user]
  end

  describe "create_correspondence/1" do
    test "creates correspondence for email to one contact", %{user: user} do
      contact = await_contact(user_id: user.id, email: "recipient@example.com")

      assert [ok: _state] =
               CQRS.create_correspondence(%{
                 id: contact.id,
                 from: "sender@example.com",
                 to: "recipient@example.com",
                 subject: "Test Email",
                 timestamp: ~N[2024-03-17 12:00:00],
                 contact_ids: [contact.id],
                 meeting_time: ~N[2024-03-16 14:00:00],
                 message_link: "https://mail.google.com/mail/u/0/#inbox/test",
                 direction: "received",
                 source: "google",
                 date: "Sun, 17 Mar 2024 12:00:00 -0600",
                 user_id: user.id,
                 thread_id: Ecto.UUID.generate()
               })

      wait_for_event(CQRS, ContactCorresponded, fn event ->
        event.direction == "received" and
          event.subject == "Test Email"
      end)
    end

    test "creates correspondence for email from one contact", %{user: user} do
      contact = await_contact(user_id: user.id, email: "sender@example.com")

      assert [ok: _state] =
               CQRS.create_correspondence(%{
                 id: contact.id,
                 from: "sender@example.com",
                 to: "recipient@example.com",
                 subject: "Test Email",
                 timestamp: ~N[2024-03-17 12:00:00],
                 contact_ids: [contact.id],
                 meeting_time: ~N[2024-03-16 14:00:00],
                 message_link: "https://mail.google.com/mail/u/0/#inbox/test",
                 direction: "sent",
                 source: "google",
                 date: "Sun, 17 Mar 2024 12:00:00 -0600",
                 user_id: user.id,
                 thread_id: Ecto.UUID.generate()
               })

      wait_for_event(CQRS, ContactCorresponded, fn event ->
        event.direction == "sent" and
          event.subject == "Test Email"
      end)
    end

    test "creates correspondence for email to two contacts", %{user: user} do
      contact1 = await_contact(user_id: user.id, email: "recipient1@example.com")
      contact2 = await_contact(user_id: user.id, email: "recipient2@example.com")

      assert [{:ok, _state1}, {:ok, _state2}] =
               CQRS.create_correspondence(%{
                 id: contact1.id,
                 from: "sender@example.com",
                 to: "recipient1@example.com",
                 subject: "Test Email",
                 timestamp: ~N[2024-03-17 12:00:00],
                 contact_ids: [contact1.id, contact2.id],
                 meeting_time: ~N[2024-03-16 14:00:00],
                 message_link: "https://mail.google.com/mail/u/0/#inbox/test",
                 direction: "sent",
                 source: "google",
                 date: "Sun, 17 Mar 2024 12:00:00 -0600",
                 user_id: user.id,
                 thread_id: Ecto.UUID.generate()
               })

      wait_for_event(CQRS, ContactCorresponded, fn event ->
        event.direction == "sent" and
          event.subject == "Test Email"
      end)

      wait_for_event(CQRS, ContactCorresponded, fn event ->
        event.direction == "sent" and
          event.subject == "Test Email"
      end)
    end

    test "creates correspondence for email from one of two contacts with same email", %{
      user: user
    } do
      contact1 = await_contact(user_id: user.id, email: "sender@example.com")
      contact2 = await_contact(user_id: user.id, email: "sender@example.com")

      assert [{:ok, _state1}, {:ok, _state2}] =
               CQRS.create_correspondence(%{
                 id: contact1.id,
                 from: "sender@example.com",
                 to: "recipient@example.com",
                 subject: "Test Email",
                 timestamp: ~N[2024-03-17 12:00:00],
                 contact_ids: [contact1.id, contact2.id],
                 meeting_time: ~N[2024-03-16 14:00:00],
                 message_link: "https://mail.google.com/mail/u/0/#inbox/test",
                 direction: "received",
                 source: "google",
                 date: "Sun, 17 Mar 2024 12:00:00 -0600",
                 user_id: user.id,
                 thread_id: Ecto.UUID.generate()
               })

      # Both contacts should receive the event since they share the email
      wait_for_event(CQRS, ContactCorresponded, fn event ->
        event.direction == "received" and
          event.subject == "Test Email"
      end)

      wait_for_event(CQRS, ContactCorresponded, fn event ->
        event.direction == "received" and
          event.subject == "Test Email"
      end)
    end

    test "creates correspondence only for known contact in multi-recipient email", %{user: user} do
      contact = await_contact(user_id: user.id, email: "known@example.com")

      email_data = %{
        id: contact.id,
        from: "sender@example.com",
        to: "known@example.com",
        subject: "Test Email",
        timestamp: ~N[2024-03-17 12:00:00],
        contact_ids: [contact.id],
        meeting_time: ~N[2024-03-16 14:00:00],
        message_link: "https://mail.google.com/mail/u/0/#inbox/test",
        direction: "sent",
        source: "google",
        date: "Sun, 17 Mar 2024 12:00:00 -0600",
        user_id: user.id,
        thread_id: Ecto.UUID.generate()
      }

      assert [ok: _state] = CQRS.create_correspondence(email_data)

      # Only the known contact should receive an event
      wait_for_event(CQRS, ContactCorresponded, fn event ->
        event.direction == "sent" and
          event.subject == "Test Email"
      end)

      # Verify no event is created for unknown recipient
      refute_receive_event(CQRS, ContactCorresponded, fn ->
        assert [ok: _state] = CQRS.create_correspondence(email_data)
      end)
    end
  end
end
