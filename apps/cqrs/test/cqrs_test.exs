defmodule CQRSTest do
  use CQRS.DataCase

  alias CQRS.Leads.Events
  alias CQRS.Leads.LeadAggregate
  alias CQRS.Meetings.Events, as: MeetingEvents

  describe "create_contact/1" do
    test "generates LeadCreated event with derived id" do
      user_id = UUID.uuid4()
      id = UUID.uuid5(:oid, "#{user_id}:remoteSource:remoteId")

      CQRS.create_contact(%{
        birthday: "1989-04-10",
        phone: "1111111111",
        remote_id: "remoteId",
        remote_source: "remoteSource",
        user_id: user_id
      })

      assert_receive_event(
        CQRS,
        Events.LeadCreated,
        fn event -> event.phone == "1111111111" end,
        fn event ->
          assert event.id == id
          assert %NaiveDateTime{} = event.timestamp
        end
      )
    end

    test "uses given timestamp" do
      now = NaiveDateTime.utc_now()

      CQRS.create_contact(%{
        anniversary: Date.utc_today(),
        phone: "2222222222",
        timestamp: now,
        user_id: UUID.uuid4()
      })

      assert_receive_event(
        CQRS,
        Events.LeadCreated,
        fn event -> event.phone == "2222222222" end,
        fn event -> assert event.timestamp == now end
      )
    end

    test "returns aggregate state" do
      assert {:ok, %{}} = CQRS.create_contact(%{phone: "3333333333", user_id: UUID.uuid4()})
    end

    test "does not generate LeadCreated event if aggregate already created" do
      user_id = UUID.uuid4()

      assert {:ok, %{id: contact_id}} =
               CQRS.create_contact(%{phone: "4444444444", user_id: user_id})

      wait_for_event(CQRS, Events.LeadCreated, fn event -> event.id == contact_id end)

      refute_receive_event(CQRS, Events.LeadCreated, fn ->
        assert {:ok, _} = CQRS.create_contact(%{phone: "4444444444", user_id: user_id})
      end)
    end

    test "generates new LeadCreated event if existing aggregate is_deleted" do
      user_id = UUID.uuid4()

      assert {:ok, %{id: contact_id}} =
               CQRS.create_contact(%{phone: "5555555550", user_id: user_id})

      wait_for_event(CQRS, Events.LeadCreated, fn event -> event.phone == "5555555550" end)

      CQRS.delete_contact(contact_id)
      wait_for_event(CQRS, Events.LeadDeleted, fn event -> event.id == contact_id end)

      assert {:ok, %{is_deleted: false}} =
               CQRS.create_contact(%{phone: "5555555551", user_id: user_id})

      wait_for_event(CQRS, Events.LeadCreated, fn event -> event.phone == "5555555551" end)
    end
  end

  describe "update_contact/1" do
    setup do
      {:ok, contact} =
        CQRS.create_contact(%{first_name: "Jimmy", phone: "1234567890", user_id: UUID.uuid4()})

      [contact: contact]
    end

    test "generates LeadUpdated event", ctx do
      assert {:ok, %{id: contact_id, first_name: "Saul"}} =
               CQRS.update_contact(ctx.contact, %{first_name: "Saul"})

      assert_receive_event(
        CQRS,
        Events.LeadUpdated,
        fn event -> event.id == contact_id end,
        fn event ->
          assert event.attrs == %{first_name: "Saul"}
          assert %NaiveDateTime{} = event.timestamp
        end
      )
    end

    test "uses given timestamp", ctx do
      now = NaiveDateTime.utc_now()

      assert {:ok, %{id: contact_id}} =
               CQRS.update_contact(ctx.contact, %{last_name: "Goodman", timestamp: now})

      assert_receive_event(
        CQRS,
        Events.LeadUpdated,
        fn event -> event.id == contact_id end,
        fn event -> assert event.timestamp == now end
      )
    end
  end

  describe "delete_contact/1" do
    setup do
      {:ok, contact} =
        CQRS.create_contact(%{first_name: "Walter", phone: "1234567890", user_id: UUID.uuid4()})

      [contact: contact]
    end

    test "generates LeadDeleted event", ctx do
      assert :ok = CQRS.delete_contact(ctx.contact.id)
      wait_for_event(CQRS, Events.LeadDeleted, fn event -> event.id == ctx.contact.id end)
    end

    test "sets aggregate state's is_deleted flag", ctx do
      assert %{is_deleted: false} = CQRS.aggregate_state(LeadAggregate, ctx.contact.id)

      assert :ok = CQRS.delete_contact(ctx.contact.id)
      wait_for_event(CQRS, Events.LeadDeleted, fn event -> event.id == ctx.contact.id end)

      assert %{is_deleted: true} = CQRS.aggregate_state(LeadAggregate, ctx.contact.id)
    end
  end

  describe "jitter_contact_ptt/2" do
    setup do
      {:ok, contact} =
        CQRS.create_contact(%{first_name: "Jesse", phone: "5551231234", user_id: UUID.uuid4()})

      [contact: contact, now: NaiveDateTime.utc_now()]
    end

    test "emits PttJittered event if jitter value changes with command", ctx do
      assert :ok = CQRS.jitter_contact_ptt(ctx.contact, %{score: 42, timestamp: ctx.now})

      wait_for_event(CQRS, Events.PttJittered, fn event ->
        event.score == 42 and event.timestamp == ctx.now
      end)
    end

    test "does not emit PttJittered event if jitter value doesn't change", ctx do
      refute_receive_event(CQRS, Events.PttJittered, fn ->
        assert :ok = CQRS.jitter_contact_ptt(ctx.contact, %{score: 0})
      end)
    end
  end

  describe "create_meeting/1" do
    test "generates MeetingCreated event with derived id" do
      user_id = UUID.uuid4()

      meeting_id = "1r95mdgvld11s4j37ae10i04is_20250207T190000Z"
      id = UUID.uuid5(:oid, "#{meeting_id}")

      start_time = NaiveDateTime.from_iso8601!("2025-02-07T12:00:00-07:00")
      end_time = NaiveDateTime.from_iso8601!("2025-02-07T13:00:00-07:00")

      CQRS.create_meeting(%{
        id: "1r95mdgvld11s4j37ae10i04is_20250207T190000Z",
        start_time: start_time,
        end_time: end_time,
        status: "confirmed",
        kind: "calendar#event",
        summary: "Lunch",
        user_id: user_id,
        sequence: 0,
        created: "2024-11-20T17:14:52.000Z",
        calendar_id: "691ea726-37f9-44c0-b752-0076bd115921",
        htmlLink:
          "https://www.google.com/calendar/event?eid=MXI5NW1kZ3ZsZDExczRqMzdhZTEwaTA0aXNfMjAyNTAyMDdUMTkwMDAwWiBqZEBoZXl3YWx0LmFp",
        etag: "\"3464245784156000\"",
        creator: %{self: true, email: "jd@heywalt.ai"},
        eventType: "default",
        iCalUID: "1r95mdgvld11s4j37ae10i04is@google.com",
        organizer: %{self: true, email: "jd@heywalt.ai"},
        originalStartTime: %{
          dateTime: "2025-02-07T12:00:00-07:00",
          timeZone: "America/Denver"
        },
        recurringEventId: "1r95mdgvld11s4j37ae10i04is",
        reminders: %{useDefault: true},
        updated: "2024-11-20T17:14:52.078Z"
      })

      assert_receive_event(
        CQRS,
        MeetingEvents.MeetingCreated,
        fn event -> event.name == "Lunch" end,
        fn event ->
          assert event.id == id
        end
      )
    end

    test "returns aggregate state" do
      calendar_id = Ecto.UUID.generate()
      id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      start_time = NaiveDateTime.from_iso8601!("2025-02-07T12:00:00-07:00")
      end_time = NaiveDateTime.from_iso8601!("2025-02-07T13:00:00-07:00")

      assert {:ok, %{name: "Meeting Event Whatever"}} =
               CQRS.create_meeting(%{
                 id: id,
                 calendar_id: calendar_id,
                 user_id: user_id,
                 summary: "Meeting Event Whatever",
                 start_time: start_time,
                 end_time: end_time,
                 status: "confirmed",
                 htmlLink:
                   "https://www.google.com/calendar/event?eid=MXI5NW1kZ3ZsZDExczRqMzdhZTEwaTA0aXNfMjAyNTAyMDdUMTkwMDAwWiBqZEBoZXl3YWx0LmFp",
                 kind: "calendar#event",
                 source_id: "Just a random string denoting the calendar event from google"
               })
    end
  end
end
