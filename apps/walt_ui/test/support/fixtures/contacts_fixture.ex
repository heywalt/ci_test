defmodule WaltUi.ContactsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `WaltUi.Contacts` context.
  """

  @doc """
  Generate a contact.
  """
  def contact_fixture(attrs \\ %{}) do
    user = WaltUi.AccountFixtures.user_fixture()
    rand_seed = Enum.random(0..2550)

    {:ok, contact} =
      attrs
      |> Enum.into(%{
        remote_source: "mobile",
        remote_id: "id-#{rand_seed}",
        first_name: "George",
        last_name: "Russell",
        email: "grussel#{rand_seed}@gmail.com",
        user_id: user.id,
        phone: "8015556923",
        ptt: 0
      })
      |> WaltUi.Contacts.create_contact()

    contact
  end

  def event_fixture(attrs \\ %{})

  def event_fixture(%{contact_id: _contact_id} = attrs) do
    {:ok, event} =
      attrs
      |> Enum.into(%{
        type: "buying",
        event: "called"
      })
      |> WaltUi.Contacts.create_event()

    event
  end

  def event_fixture(attrs) do
    %{id: contact_id} = contact_fixture()

    attrs
    |> Enum.into(%{contact_id: contact_id})
    |> event_fixture()
  end
end
