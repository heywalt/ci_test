defmodule WaltUi.Projectors.ContactTest do
  use WaltUi.CqrsCase

  import AssertAsync
  import WaltUi.Factory

  alias CQRS.Leads.Commands, as: Cmd
  alias CQRS.Leads.Events.AddressSelected
  alias CQRS.Leads.Events.LeadCreated
  alias CQRS.Leads.Events.LeadUnified
  alias CQRS.Leads.Events.LeadUpdated
  alias WaltUi.Projections.Contact

  describe "LeadCreated event" do
    test "normalizes a phone number into the standard_phone field" do
      user = insert(:user)

      append_event(%LeadCreated{
        id: Ecto.UUID.generate(),
        phone: "+1 (555) 123-5555",
        timestamp: NaiveDateTime.utc_now(),
        user_id: user.id
      })

      assert_async do
        assert [%{phone: "+1 (555) 123-5555", standard_phone: "5551235555"}] = Repo.all(Contact)
      end
    end

    test "ignores phone numbers that cannot be normalized" do
      user = insert(:user)

      append_event(%LeadCreated{
        id: Ecto.UUID.generate(),
        phone: "1234",
        timestamp: NaiveDateTime.utc_now(),
        user_id: user.id
      })

      assert_async do
        assert [%{phone: "1234", standard_phone: nil}] = Repo.all(Contact)
      end
    end

    test "projects multiple phone numbers" do
      :contact
      |> params_for(
        phone: "1 801-123-1234",
        phone_numbers: [
          %{label: "home", phone: "1 801-123-1234"},
          %{label: "work", phone: "555-123-1234"}
        ]
      )
      |> CQRS.create_contact(consistency: :strong)

      [contact] = Repo.all(Contact)

      verified_phones = [
        %{label: "home", phone: "1 801-123-1234", standard_phone: "8011231234"},
        %{label: "work", phone: "555-123-1234", standard_phone: "5551231234"}
      ]

      Enum.map(contact.phone_numbers, fn phone ->
        assert %{label: phone.label, phone: phone.phone, standard_phone: phone.standard_phone} in verified_phones
      end)
    end

    test "projects multiple emails" do
      :contact
      |> params_for(
        emails: [
          %{label: "home", email: "test@test.com"},
          %{label: "work", email: "test2@test.com"}
        ]
      )
      |> CQRS.create_contact(consistency: :strong)

      [contact] = Repo.all(Contact)

      verified_emails = [
        %{label: "home", email: "test@test.com"},
        %{label: "work", email: "test2@test.com"}
      ]

      Enum.map(contact.emails, fn email ->
        assert %{label: email.label, email: email.email} in verified_emails
      end)
    end
  end

  describe "LeadUpdated event" do
    test "normalizes a phone number change" do
      contact = insert(:contact, phone: "555-123-123")

      append_event(%LeadUpdated{
        id: contact.id,
        attrs: %{phone: "555-123-1234"},
        metadata: [],
        timestamp: NaiveDateTime.utc_now(),
        user_id: contact.user_id
      })

      assert_async do
        assert %{standard_phone: "5551231234"} = Repo.reload(contact)
      end
    end
  end

  describe "LeadUnified event" do
    test "updates contact's enrichment_id" do
      contact = insert(:contact, enrichment_id: nil, ptt: 0)
      enrich_id = Ecto.UUID.generate()

      append_event(%LeadUnified{
        id: contact.id,
        enrichment_id: enrich_id,
        ptt: 42,
        timestamp: NaiveDateTime.utc_now()
      })

      assert_async do
        assert %{enrichment_id: ^enrich_id, ptt: 42} = Repo.reload(contact)
      end
    end

    test "adding a phone number to a contact adds it to the phone_numbers field" do
      :contact
      |> params_for(phone: "555-123-123")
      |> CQRS.create_contact(consistency: :strong)

      [contact] = Repo.all(Contact)
      # No phone numbers on a new contact
      assert [] = contact.phone_numbers

      # Update the contact with a phone number
      CQRS.update_contact(
        contact,
        %{phone: "555-123-1234", phone_numbers: [%{label: "home", phone: "555-123-1234"}]},
        consistency: :strong
      )

      # Verify that the phone number is added to the phone_numbers field
      assert %{phone_numbers: [%{phone: "555-123-1234", standard_phone: "5551231234"}]} =
               Repo.reload(contact)
    end

    test "adding multiple phone numbers to a contact during an update adds them to the phone_numbers field" do
      :contact
      |> params_for(phone: "555-123-123")
      |> CQRS.create_contact(consistency: :strong)

      [contact] = Repo.all(Contact)

      assert [] = contact.phone_numbers

      CQRS.update_contact(
        contact,
        %{
          phone: "555-123-1234",
          phone_numbers: [
            %{label: "home", phone: "555-123-1234"},
            %{label: "work", phone: "555-123-5678"}
          ]
        },
        consistency: :strong
      )

      [contact] = Repo.all(Contact)

      assert length(contact.phone_numbers) == 2

      Enum.map(contact.phone_numbers, fn phone ->
        assert %{label: phone.label, phone: phone.phone, standard_phone: phone.standard_phone} in [
                 %{label: "home", phone: "555-123-1234", standard_phone: "5551231234"},
                 %{label: "work", phone: "555-123-5678", standard_phone: "5551235678"}
               ]
      end)
    end

    test "adding an email to a contact adds it to the emails field" do
      :contact
      |> params_for(email: "test@test.com")
      |> CQRS.create_contact(consistency: :strong)

      [contact] = Repo.all(Contact)

      assert [] = contact.emails

      CQRS.update_contact(
        contact,
        %{emails: [%{label: "home", email: "test@test.com"}]},
        consistency: :strong
      )

      assert %{emails: [%{label: "home", email: "test@test.com"}]} = Repo.reload(contact)
    end

    test "removing a phone number from a contact removes it from the phone_numbers field" do
      :contact
      |> params_for(
        phone: "1 801-123-1234",
        phone_numbers: [
          %{label: "home", phone: "1 801-123-1234"},
          %{label: "work", phone: "555-123-1234"}
        ]
      )
      |> CQRS.create_contact(consistency: :strong)

      [contact] = Repo.all(Contact)

      assert length(contact.phone_numbers) == 2

      # Update the contact with a phone number
      CQRS.update_contact(
        contact,
        %{phone: "555-123-1234", phone_numbers: [%{label: "work", phone: "555-123-1234"}]},
        consistency: :strong
      )

      [contact] = Repo.all(Contact)

      assert length(contact.phone_numbers) == 1

      Enum.map(contact.phone_numbers, fn phone ->
        assert %{label: phone.label, phone: phone.phone, standard_phone: phone.standard_phone} in [
                 %{label: "work", phone: "555-123-1234", standard_phone: "5551231234"}
               ]
      end)
    end

    test "adding multiple emails to a contact during an updateadds them to the emails field" do
      :contact
      |> params_for(emails: [])
      |> CQRS.create_contact(consistency: :strong)

      [contact] = Repo.all(Contact)

      assert [] = contact.emails

      CQRS.update_contact(
        contact,
        %{
          emails: [
            %{label: "home", email: "test@test.com"},
            %{label: "work", email: "test2@test.com"}
          ]
        },
        consistency: :strong
      )

      assert %{
               emails: [
                 %{label: "home", email: "test@test.com"},
                 %{label: "work", email: "test2@test.com"}
               ]
             } = Repo.reload(contact)
    end

    test "removing an email from a contact removes it from the emails field" do
      :contact
      |> params_for(
        emails: [
          %{label: "home", email: "test@test.com"},
          %{label: "work", email: "test2@test.com"}
        ]
      )
      |> CQRS.create_contact(consistency: :strong)

      [contact] = Repo.all(Contact)

      assert length(contact.emails) == 2

      CQRS.update_contact(
        contact,
        %{emails: [%{label: "work", email: "test2@test.com"}]},
        consistency: :strong
      )

      [contact] = Repo.all(Contact)

      assert length(contact.emails) == 1

      Enum.map(contact.emails, fn email ->
        assert %{label: email.label, email: email.email} in [
                 %{label: "work", email: "test2@test.com"}
               ]
      end)
    end
  end

  describe "AddressSelected event" do
    test "updates contact address" do
      contact =
        await_contact(
          street_1: "123 Main St",
          street_2: "#42",
          city: "Fooville",
          state: "OH",
          zip: "43113"
        )

      append_event(%AddressSelected{
        id: contact.id,
        street_1: "42 W Broad St",
        street_2: nil,
        city: "Townton",
        state: "FL",
        zip: "11111"
      })

      assert_async do
        assert %{
                 street_1: "42 W Broad St",
                 street_2: nil,
                 city: "Townton",
                 state: "FL",
                 zip: "11111"
               } = Repo.reload(contact)
      end
    end
  end

  describe "PttHistoryReset event" do
    test "updates contact Move Score to 0" do
      contact = await_contact(ptt: 42)
      cmd = %Cmd.ResetPttHistory{id: contact.id, reason: "test"}

      CQRS.dispatch(cmd, consistency: :strong)

      assert %{ptt: 0} = Repo.get(Contact, contact.id)
    end
  end
end
