defmodule WaltUi.CalendarsTest do
  use Repo.DataCase

  import WaltUi.Factory

  alias WaltUi.Calendars
  alias WaltUi.Calendars.Calendar

  setup do
    user = insert(:user)

    {:ok, %{user: user}}
  end

  describe "create/1" do
    test "creates a new calendar with valid attributes", %{user: user} do
      attrs = valid_calendar_attrs()

      assert {:ok, calendar} = Calendars.create(attrs, user, :google)
      assert calendar.source_id == attrs.id
      assert calendar.source == :google
      assert calendar.user_id == user.id
      assert calendar.name == attrs.summary
    end

    test "returns an error when a required field is missing", %{user: user} do
      attrs = valid_calendar_attrs()

      assert {:error, %Ecto.Changeset{}} = Calendars.create(attrs, user, nil)
    end
  end

  describe "list/1" do
    test "lists all calendars for a given user", %{user: user} do
      attrs = valid_calendar_attrs()

      attrs2 = %{
        id: "superlongdumbid",
        summary: "second calendar",
        backgroundColor: "#bada55",
        timeZone: "America/Denver"
      }

      Enum.map([attrs, attrs2], &Calendars.create(&1, user, :google))

      assert [%Calendar{}, %Calendar{}] = Calendars.list(user.id)
    end
  end

  describe "update/2" do
    test "updates an existing calendar", %{user: user} do
      attrs = valid_calendar_attrs()

      assert {:ok, calendar} = Calendars.create(attrs, user, :google)

      assert {:ok, %Calendar{name: "Fancy New Calendar Name"}} =
               Calendars.update(calendar, %{name: "Fancy New Calendar Name"})
    end
  end

  describe "delete/1" do
    test "deletes an existing calendar", %{user: user} do
      attrs = valid_calendar_attrs()

      assert {:ok, calendar} = Calendars.create(attrs, user, :google)

      assert {:ok, %Calendar{}} = Calendars.delete(calendar)
    end
  end

  defp valid_calendar_attrs do
    %{
      id:
        "c_359112f71e86d3e7364881a01c232c45f2d733a41a5ac7f649a18af9aecf8602@group.calendar.google.com",
      selected: true,
      description: "I guess meetings I'll have with real estate-related individuals.",
      kind: "calendar#calendarListEntry",
      summary: "Real Estate Meetings",
      accessRole: "owner",
      backgroundColor: "#b99aff",
      colorId: "18",
      conferenceProperties: %{"allowedConferenceSolutionTypes" => ["hangoutsMeet"]},
      defaultReminders: [],
      etag: "\"1738880777256000\"",
      foregroundColor: "#000000",
      timeZone: "America/Denver"
    }
  end
end
