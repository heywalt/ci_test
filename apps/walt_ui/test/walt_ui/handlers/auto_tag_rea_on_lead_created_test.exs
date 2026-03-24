defmodule WaltUi.Handlers.AutoTagReaOnLeadCreatedTest do
  use WaltUi.CqrsCase, async: false

  import WaltUi.Factory

  alias CQRS.Leads.Events.LeadCreated
  alias WaltUi.Contacts
  alias WaltUi.ContactTags
  alias WaltUi.Handlers.AutoTagReaOnLeadCreated
  alias WaltUi.Tags

  describe "handle/2 tagging" do
    test "tags contact as 'Real Estate Agent' when email matches" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "jane@kw.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      assert Enum.any?(tags, &(&1.name == "Real Estate Agent"))
    end

    test "tags contact when emails field contains a matching email" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        emails: [%{"email" => "work@exprealty.com", "label" => "work"}],
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      assert Enum.any?(tags, &(&1.name == "Real Estate Agent"))
    end

    test "tags contact when email matches a substring pattern" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "salsellshomes@gmail.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      assert Enum.any?(tags, &(&1.name == "Real Estate Agent"))
    end

    test "does not tag contact when no email matches" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "jane@gmail.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      assert tags == []
    end

    test "does not tag contact when there are no emails" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      assert tags == []
    end

    test "is idempotent" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "jane@kw.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})
      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      rea_tags = Enum.filter(tags, &(&1.name == "Real Estate Agent"))
      assert length(rea_tags) == 1
    end

    test "reuses the same tag across contacts for the same user" do
      user = insert(:user)
      contact_1 = insert(:contact, user_id: user.id)
      contact_2 = insert(:contact, user_id: user.id)

      event_1 = %LeadCreated{
        id: contact_1.id,
        user_id: user.id,
        email: "jane@kw.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      event_2 = %LeadCreated{
        id: contact_2.id,
        user_id: user.id,
        email: "bob@exprealty.com",
        phone: "555-5678",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event_1, %{})
      assert :ok = AutoTagReaOnLeadCreated.handle(event_2, %{})

      user_tags = Tags.list_tags(user.id)
      rea_tags = Enum.filter(user_tags, &(&1.name == "Real Estate Agent"))
      assert length(rea_tags) == 1
    end
  end

  describe "handle/2 system user matching" do
    test "tags contact when email matches a system user's email" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)
      _other_user = insert(:user, email: "colleague@gmail.com")

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "colleague@gmail.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      assert Enum.any?(tags, &(&1.name == "Real Estate Agent"))
    end

    test "tags contact when email matches an external account's email" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)
      _external_account = insert(:external_account, email: "colleague_ext@gmail.com")

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "colleague_ext@gmail.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      assert Enum.any?(tags, &(&1.name == "Real Estate Agent"))
    end

    test "does not tag when email does not match any pattern or system user" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "random_person@gmail.com",
        phone: "555-1234",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      tags = ContactTags.list_tags_for_contact(contact.id)
      assert tags == []
    end
  end

  describe "handle/2 hiding" do
    test "hides contact when email matches" do
      user = insert(:user)

      {:ok, _aggregate} =
        CQRS.create_contact(
          %{
            user_id: user.id,
            phone: "5551234567",
            email: "jane@kw.com",
            remote_source: "test",
            remote_id: "hide-test-1"
          },
          consistency: :strong
        )

      contact = Contacts.get_contact(user.id, "test", "hide-test-1")

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "jane@kw.com",
        phone: "5551234567",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      updated_contact = Contacts.get_contact(contact.id)
      assert updated_contact.is_hidden == true
    end

    test "does not hide contact when no email matches" do
      user = insert(:user)

      {:ok, _aggregate} =
        CQRS.create_contact(
          %{
            user_id: user.id,
            phone: "5559876543",
            email: "jane@gmail.com",
            remote_source: "test",
            remote_id: "hide-test-2"
          },
          consistency: :strong
        )

      contact = Contacts.get_contact(user.id, "test", "hide-test-2")

      event = %LeadCreated{
        id: contact.id,
        user_id: user.id,
        email: "jane@gmail.com",
        phone: "5559876543",
        timestamp: ~N[2023-01-01 00:00:00]
      }

      assert :ok = AutoTagReaOnLeadCreated.handle(event, %{})

      updated_contact = Contacts.get_contact(contact.id)
      assert updated_contact.is_hidden == false
    end
  end
end
