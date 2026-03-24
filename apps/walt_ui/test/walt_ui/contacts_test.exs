defmodule WaltUi.ContactsTest do
  use WaltUi.CqrsCase
  use Mimic

  import WaltUi.Factory

  alias WaltUi.Contacts

  describe "bulk_create/1" do
    setup :set_mimic_global

    setup do
      [user: insert(:user)]
    end

    test "publishes events for each contact", ctx do
      one = %{phone: "111-111-1111", remote_id: Ecto.UUID.generate(), user_id: ctx.user.id}
      two = %{phone: "222-222-2222", remote_id: Ecto.UUID.generate(), user_id: ctx.user.id}

      assert :ok = Contacts.bulk_create([one, two])

      wait_for_event(CQRS, CQRS.Leads.Events.LeadCreated, fn created ->
        not is_nil(created.id) and created.phone == "111-111-1111"
      end)

      wait_for_event(CQRS, CQRS.Leads.Events.LeadCreated, fn created ->
        not is_nil(created.id) and created.phone == "222-222-2222"
      end)
    end
  end

  describe "create_contacts_from_csv/3" do
    setup do
      [user: insert(:user)]
    end

    test "creates contacts from a CSV file", %{
      user: user
    } do
      path = Path.join([Path.expand(".."), "walt_ui", "test", "support", "sample_contacts.csv"])
      create_fun = fn _user, chunk -> send(self(), chunk) end

      # assert the number of rows that were "processed"
      assert 4 = Contacts.create_contacts_from_csv(path, user, create_fun: create_fun)

      assert_receive [
        %{
          "phone" => _,
          "first_name" => _,
          "last_name" => _,
          "email" => _,
          "updated_at" => _,
          "inserted_at" => _,
          "remote_id" => _,
          "remote_source" => "csv"
        }
        | _
      ]
    end

    test "includes tags column from CSV in contact data", %{user: user} do
      path = Path.join([Path.expand(".."), "walt_ui", "test", "support", "sample_contacts.csv"])
      create_fun = fn _user, chunk -> send(self(), chunk) end

      assert 4 = Contacts.create_contacts_from_csv(path, user, create_fun: create_fun)

      assert_receive chunk

      # Find Steven Colbert with tags
      steven = Enum.find(chunk, &(&1["first_name"] == "Steven" && &1["last_name"] == "Colbert"))
      assert steven["tags"] == "VIP,Friend"

      # Find John Oliver with tags
      john = Enum.find(chunk, &(&1["first_name"] == "John" && &1["last_name"] == "Oliver"))
      assert john["tags"] == "VIP,Important"

      # Find Matt Mercer with single tag
      matt = Enum.find(chunk, &(&1["first_name"] == "Matt" && &1["last_name"] == "Mercer"))
      assert matt["tags"] == "Lead"

      # Find Johnathan Lamb with no tags
      johnathan =
        Enum.find(chunk, &(&1["first_name"] == "Johnathan" && &1["last_name"] == "Lamb"))

      assert johnathan["tags"] == ""
    end
  end

  describe "ptt_history/1" do
    setup do
      [
        contact: insert(:contact),
        timestamp: fn n -> Date.utc_today() |> Date.add(n) |> NaiveDateTime.new!(~T[00:00:00]) end
      ]
    end

    test "returns a list of Move Scores in reverse chronological order", ctx do
      insert(:ptt_score, contact_id: ctx.contact.id, occurred_at: ctx.timestamp.(-8), score: 42)
      insert(:ptt_score, contact_id: ctx.contact.id, occurred_at: ctx.timestamp.(0), score: 14)

      assert [%{score: 14}, %{score: 42}] = Contacts.ptt_history(ctx.contact.id)
    end

    test "returns an empty list if contact has no Move Scores", ctx do
      assert Contacts.ptt_history(ctx.contact.id) == []
    end

    test "returns no more than 12 scores", ctx do
      Enum.each(0..15, fn i ->
        insert(:ptt_score, contact_id: ctx.contact.id, occurred_at: ctx.timestamp.(i * -8))
      end)

      history = Contacts.ptt_history(ctx.contact.id)
      assert length(history) == 12
    end
  end

  describe "exclude_realtors/1" do
    setup do
      [user: insert(:user)]
    end

    test "excludes contact whose email matches a realtor identity", ctx do
      contact = insert(:contact, user_id: ctx.user.id, email: "agent@realty.com")

      insert(:realtor_identity, email: "agent@realty.com")

      results =
        from(c in WaltUi.Projections.Contact, where: c.user_id == ^ctx.user.id)
        |> Contacts.exclude_realtors()
        |> Repo.all()

      refute Enum.any?(results, &(&1.id == contact.id))
    end

    test "excludes contact whose standard_phone matches a realtor phone number", ctx do
      contact =
        insert(:contact, user_id: ctx.user.id, email: nil, standard_phone: "8015551234")

      insert(:realtor_phone_number, number: "8015551234")

      results =
        from(c in WaltUi.Projections.Contact, where: c.user_id == ^ctx.user.id)
        |> Contacts.exclude_realtors()
        |> Repo.all()

      refute Enum.any?(results, &(&1.id == contact.id))
    end

    test "excludes contact matching on both email and phone", ctx do
      contact =
        insert(:contact,
          user_id: ctx.user.id,
          email: "agent@realty.com",
          standard_phone: "8015551234"
        )

      insert(:realtor_identity, email: "agent@realty.com")
      insert(:realtor_phone_number, number: "8015551234")

      results =
        from(c in WaltUi.Projections.Contact, where: c.user_id == ^ctx.user.id)
        |> Contacts.exclude_realtors()
        |> Repo.all()

      refute Enum.any?(results, &(&1.id == contact.id))
    end

    test "keeps contact with no realtor match", ctx do
      contact =
        insert(:contact,
          user_id: ctx.user.id,
          email: "buyer@gmail.com",
          standard_phone: "8015559999"
        )

      insert(:realtor_identity, email: "agent@realty.com")
      insert(:realtor_phone_number, number: "8015551234")

      results =
        from(c in WaltUi.Projections.Contact, where: c.user_id == ^ctx.user.id)
        |> Contacts.exclude_realtors()
        |> Repo.all()

      assert Enum.any?(results, &(&1.id == contact.id))
    end

    test "keeps contact with nil email and nil standard_phone", ctx do
      contact =
        insert(:contact, user_id: ctx.user.id, email: nil, standard_phone: nil)

      insert(:realtor_identity, email: "agent@realty.com")
      insert(:realtor_phone_number, number: "8015551234")

      results =
        from(c in WaltUi.Projections.Contact, where: c.user_id == ^ctx.user.id)
        |> Contacts.exclude_realtors()
        |> Repo.all()

      assert Enum.any?(results, &(&1.id == contact.id))
    end

    test "email match is case-insensitive (citext)", ctx do
      contact = insert(:contact, user_id: ctx.user.id, email: "Agent@Realty.COM")

      insert(:realtor_identity, email: "agent@realty.com")

      results =
        from(c in WaltUi.Projections.Contact, where: c.user_id == ^ctx.user.id)
        |> Contacts.exclude_realtors()
        |> Repo.all()

      refute Enum.any?(results, &(&1.id == contact.id))
    end

    test "excludes on email match even when phone does not match", ctx do
      contact =
        insert(:contact,
          user_id: ctx.user.id,
          email: "agent@realty.com",
          standard_phone: "8015559999"
        )

      insert(:realtor_identity, email: "agent@realty.com")

      results =
        from(c in WaltUi.Projections.Contact, where: c.user_id == ^ctx.user.id)
        |> Contacts.exclude_realtors()
        |> Repo.all()

      refute Enum.any?(results, &(&1.id == contact.id))
    end

    test "excludes on phone match even when email does not match", ctx do
      contact =
        insert(:contact,
          user_id: ctx.user.id,
          email: "buyer@gmail.com",
          standard_phone: "8015551234"
        )

      insert(:realtor_phone_number, number: "8015551234")

      results =
        from(c in WaltUi.Projections.Contact, where: c.user_id == ^ctx.user.id)
        |> Contacts.exclude_realtors()
        |> Repo.all()

      refute Enum.any?(results, &(&1.id == contact.id))
    end
  end

  describe "list_contacts_by_user/1" do
    setup do
      [freemium: insert(:user, tier: :freemium), premium: insert(:user, tier: :premium)]
    end

    test "returns all the contacts for a user", ctx do
      %{id: contact_id} = insert(:contact, user_id: ctx.freemium.id)
      assert [%{id: ^contact_id}] = Contacts.list_contacts_by_user(ctx.freemium.id)
    end

    test "sorts by showcase status for freemium user", ctx do
      insert_list(7, :contact, user_id: ctx.freemium.id, ptt: 99)
      showcased = insert(:contact, user_id: ctx.freemium.id, ptt: 12)
      insert_list(4, :contact, user_id: ctx.freemium.id, ptt: 42)

      insert(:contact_showcase, contact_id: showcased.id, user_id: ctx.freemium.id)

      assert [%{id: first_id} | _rest] = Contacts.list_contacts_by_user(ctx.freemium.id)
      assert first_id == showcased.id
    end

    test "does not sort by showcase for premium user", ctx do
      insert_list(7, :contact, user_id: ctx.premium.id, ptt: 99)
      showcased = insert(:contact, user_id: ctx.premium.id, ptt: 12)
      insert_list(4, :contact, user_id: ctx.premium.id, ptt: 42)

      insert(:contact_showcase, contact_id: showcased.id, user_id: ctx.premium.id)

      assert [%{id: first_id} | _rest] = Contacts.list_contacts_by_user(ctx.premium.id)
      assert first_id != showcased.id
    end

    test "falls back to first_name sort", ctx do
      insert(:contact, user_id: ctx.premium.id, ptt: 42, first_name: "Z")
      insert(:contact, user_id: ctx.premium.id, ptt: 42, first_name: "C")
      insert(:contact, user_id: ctx.premium.id, ptt: 42, first_name: "Y")
      insert(:contact, user_id: ctx.premium.id, ptt: 42, first_name: "M")
      insert(:contact, user_id: ctx.premium.id, ptt: 42, first_name: "B")

      assert [
               %{first_name: "B"},
               %{first_name: "C"},
               %{first_name: "M"},
               %{first_name: "Y"},
               %{first_name: "Z"}
             ] = Contacts.list_contacts_by_user(ctx.premium.id)
    end

    test "excludes contacts who are realtors", ctx do
      _realtor_contact = insert(:contact, user_id: ctx.premium.id, email: "agent@realty.com")
      non_realtor_1 = insert(:contact, user_id: ctx.premium.id, email: "buyer1@gmail.com")
      non_realtor_2 = insert(:contact, user_id: ctx.premium.id, email: "buyer2@gmail.com")

      insert(:realtor_identity, email: "agent@realty.com")

      results = Contacts.list_contacts_by_user(ctx.premium.id)
      result_ids = Enum.map(results, & &1.id)

      assert length(results) == 2
      assert non_realtor_1.id in result_ids
      assert non_realtor_2.id in result_ids
    end

    test "returns non-realtor contacts with sorting preserved", ctx do
      contact_high = insert(:contact, user_id: ctx.premium.id, email: "high@gmail.com", ptt: 90)
      contact_low = insert(:contact, user_id: ctx.premium.id, email: "low@gmail.com", ptt: 10)

      insert(:realtor_identity, email: "unrelated@realty.com")

      results = Contacts.list_contacts_by_user(ctx.premium.id)
      result_ids = Enum.map(results, & &1.id)

      assert length(results) == 2
      assert List.first(result_ids) == contact_high.id
      assert List.last(result_ids) == contact_low.id
    end
  end

  describe "hidden_contacts_by_user_query/1" do
    test "does NOT exclude realtors" do
      user = insert(:user)

      hidden_realtor =
        insert(:contact, user_id: user.id, email: "agent@realty.com", is_hidden: true)

      insert(:realtor_identity, email: "agent@realty.com")

      results =
        user.id
        |> Contacts.hidden_contacts_by_user_query()
        |> Repo.all()

      result_ids = Enum.map(results, & &1.id)
      assert hidden_realtor.id in result_ids
    end
  end

  describe "get_contact/1" do
    test "returns the contact with given id" do
      %{id: contact_id} = insert(:contact)
      assert %{id: ^contact_id} = Contacts.get_contact(contact_id)
    end
  end

  describe "get_top_contacts/1" do
    setup do
      user = insert(:user, email: "cantbeduplicated@heywalt.ai", tier: :premium)
      contact_1 = insert(:contact, user_id: user.id, ptt: 0)
      contact_2 = insert(:contact, user_id: user.id, ptt: 65)
      contact_3 = insert(:contact, user_id: user.id, ptt: 85)
      contact_4 = insert(:contact, user_id: user.id, ptt: 97)

      {:ok,
       %{
         contact_1: contact_1,
         contact_2: contact_2,
         contact_3: contact_3,
         contact_4: contact_4,
         user: user
       }}
    end

    test "returns the top 3 contacts for a user", %{
      contact_2: contact_2,
      contact_3: contact_3,
      contact_4: contact_4,
      user: user
    } do
      ids = Enum.map([contact_2, contact_3, contact_4], & &1.id)
      assert top_contacts = [_, _, _] = Contacts.get_top_contacts(user.id)
      Enum.each(top_contacts, fn %{id: id} -> assert id in ids end)
    end

    test "if highlighted contacts exist for today, return those", %{user: user} do
      highlight_ids =
        [
          build(:contact, ptt: 65, user_id: user.id),
          build(:contact, ptt: 85, user_id: user.id),
          build(:contact, ptt: 97, user_id: user.id)
        ]
        |> Enum.map(&insert(:contact_highlight, contact: &1, user: user))
        |> Enum.map(& &1.contact_id)

      top_contacts = [_, _, _] = Contacts.get_top_contacts(user.id)
      Enum.each(top_contacts, fn %{id: id} -> assert id in highlight_ids end)
    end

    test "if highlighted contacts exist for yesterday, return new contacts", %{
      contact_2: contact_2,
      contact_3: contact_3,
      contact_4: contact_4,
      user: user
    } do
      yesterday =
        DateTime.utc_now()
        |> DateTime.shift_zone!("America/Denver")
        |> DateTime.to_naive()
        |> NaiveDateTime.add(-1, :day)

      highlight_ids =
        [
          build(:contact, ptt: 65, user_id: user.id),
          build(:contact, ptt: 85, user_id: user.id),
          build(:contact, ptt: 97, user_id: user.id)
        ]
        |> Enum.map(&insert(:contact_highlight, contact: &1, user: user, inserted_at: yesterday))
        |> Enum.map(& &1.contact_id)

      existing_ids = [contact_2.id, contact_3.id, contact_4.id]
      top_contacts = [_, _, _] = Contacts.get_top_contacts(user.id)

      # Ensure that the highlighted contacts from yesterday are not returned
      Enum.each(top_contacts, fn %{id: id} ->
        refute id in highlight_ids
      end)

      # Ensure new top contacts are highlighted
      Enum.each(top_contacts, fn %{id: id} ->
        assert id in existing_ids
      end)
    end

    test "freemium users can only highlight showcased contacts" do
      user = insert(:user, tier: :freemium)
      contacts = insert_list(3, :contact, ptt: 51, user_id: user.id)

      assert [] = Contacts.get_top_contacts(user.id)

      Enum.each(contacts, &insert(:contact_showcase, contact_id: &1.id, user_id: user.id))
      assert [_, _, _] = Contacts.get_top_contacts(user.id)
    end

    test "excludes realtors from new top 3 selection" do
      user = insert(:user, tier: :premium)

      realtor_contact =
        insert(:contact, user_id: user.id, ptt: 80, email: "agent@realty.com")

      non_realtor_1 = insert(:contact, user_id: user.id, ptt: 75)
      non_realtor_2 = insert(:contact, user_id: user.id, ptt: 70)

      insert(:realtor_identity, email: "agent@realty.com")

      results = Contacts.get_top_contacts(user.id)
      result_ids = Enum.map(results, & &1.id)

      assert length(results) == 2
      refute realtor_contact.id in result_ids
      assert non_realtor_1.id in result_ids
      assert non_realtor_2.id in result_ids
    end

    test "excludes realtors from today's highlighted contacts" do
      user = insert(:user, tier: :premium)

      highlights =
        [
          build(:contact, ptt: 65, user_id: user.id),
          build(:contact, ptt: 85, user_id: user.id),
          build(:contact, ptt: 97, user_id: user.id, email: "agent@realty.com")
        ]
        |> Enum.map(&insert(:contact_highlight, contact: &1, user: user))

      realtor_highlight = List.last(highlights)

      insert(:realtor_identity, email: "agent@realty.com")

      results = Contacts.get_top_contacts(user.id)
      result_ids = Enum.map(results, & &1.id)

      assert length(results) == 2
      refute realtor_highlight.contact_id in result_ids
    end
  end

  describe "get_enrichment_report/1" do
    setup do
      [user: insert(:user, email: "fancy_user@heywalt.ai")]
    end

    test "returns empty lists when user has no contacts", ctx do
      assert %{top: [], bottom: []} = Contacts.get_enrichment_report(ctx.user.id)
    end

    test "returns empty lists when contacts have no Move Scores", ctx do
      insert(:contact, user_id: ctx.user.id)
      insert(:contact, user_id: ctx.user.id)
      insert(:contact, user_id: ctx.user.id)

      assert %{top: [], bottom: []} = Contacts.get_enrichment_report(ctx.user.id)
    end

    test "returns contacts with biggest Move Score changes", ctx do
      # Create contacts with increasing and decreasing scores
      mike = insert(:contact, user_id: ctx.user.id, first_name: "Mike", last_name: "Peregrina")
      drew = insert(:contact, user_id: ctx.user.id, first_name: "Drew", last_name: "Fravert")
      jaxon = insert(:contact, user_id: ctx.user.id, first_name: "Jaxon", last_name: "Evans")
      johnson = insert(:contact, user_id: ctx.user.id, first_name: "Johnson", last_name: "Denen")
      jd = insert(:contact, user_id: ctx.user.id, first_name: "JD", last_name: "Skinner")

      # Mike goes up
      insert(:ptt_score, contact_id: mike.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: mike.id, occurred_at: timestamp(0), score: 50)

      # Drew goes down
      insert(:ptt_score, contact_id: drew.id, occurred_at: timestamp(-7), score: 50)
      insert(:ptt_score, contact_id: drew.id, occurred_at: timestamp(0), score: 10)

      # Jaxon goes up
      insert(:ptt_score, contact_id: jaxon.id, occurred_at: timestamp(-7), score: 20)
      insert(:ptt_score, contact_id: jaxon.id, occurred_at: timestamp(0), score: 80)

      # Johnson goes down
      insert(:ptt_score, contact_id: johnson.id, occurred_at: timestamp(-7), score: 50)
      insert(:ptt_score, contact_id: johnson.id, occurred_at: timestamp(0), score: 10)

      # JD doesn't have a previous score; he's new and shouldn't show up in the results
      insert(:ptt_score, contact_id: jd.id, occurred_at: timestamp(0), score: 10)

      result = Contacts.get_enrichment_report(ctx.user.id)

      assert length(result.top) == 2
      assert length(result.bottom) == 2

      top_ids = Enum.map(result.top, fn res -> res.contact.id end)
      bottom_ids = Enum.map(result.bottom, fn res -> res.contact.id end)

      assert mike.id in top_ids
      assert jaxon.id in top_ids
      assert drew.id in bottom_ids
      assert johnson.id in bottom_ids
      refute jd.id in top_ids and jd.id in bottom_ids
    end

    test "only returns 5 contacts for top category", ctx do
      # Create contacts with increasing and decreasing scores
      mike = insert(:contact, user_id: ctx.user.id, first_name: "Mike", last_name: "Peregrina")
      drew = insert(:contact, user_id: ctx.user.id, first_name: "Drew", last_name: "Fravert")
      jaxon = insert(:contact, user_id: ctx.user.id, first_name: "Jaxon", last_name: "Evans")
      veronica = insert(:contact, user_id: ctx.user.id, first_name: "Veronica", last_name: "Mars")
      jules = insert(:contact, user_id: ctx.user.id, first_name: "Jules", last_name: "Brenner")
      caitlyn = insert(:contact, user_id: ctx.user.id, first_name: "Caitlyn", last_name: "Smith")

      # Mike goes up
      insert(:ptt_score, contact_id: mike.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: mike.id, occurred_at: timestamp(0), score: 50)

      insert(:ptt_score, contact_id: drew.id, occurred_at: timestamp(-7), score: 20)
      insert(:ptt_score, contact_id: drew.id, occurred_at: timestamp(0), score: 40)

      insert(:ptt_score, contact_id: jaxon.id, occurred_at: timestamp(-7), score: 20)
      insert(:ptt_score, contact_id: jaxon.id, occurred_at: timestamp(0), score: 80)

      insert(:ptt_score, contact_id: veronica.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: veronica.id, occurred_at: timestamp(0), score: 20)

      insert(:ptt_score, contact_id: jules.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: jules.id, occurred_at: timestamp(0), score: 15)

      insert(:ptt_score, contact_id: caitlyn.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: caitlyn.id, occurred_at: timestamp(0), score: 80)

      result = Contacts.get_enrichment_report(ctx.user.id)

      top_ids = Enum.map(result.top, fn res -> res.contact.id end)

      assert length(result.top) == 5
      assert result.bottom == []

      # Jules is not in the top 5, because she was the lowest increase
      refute jules.id in top_ids
    end

    test "handles contacts with no previous scores", %{user: user} do
      contact = insert(:contact, user_id: user.id, first_name: "New", last_name: "Contact")
      insert(:ptt_score, contact_id: contact.id, occurred_at: NaiveDateTime.utc_now(), score: 50)

      result = Contacts.get_enrichment_report(user.id)

      # Contacts with no previous scores should not show up in the results
      assert result.top == []
      assert result.bottom == []
    end
  end

  describe "list_all_emails/1" do
    test "returns unique emails from primary email field and emails array" do
      user = insert(:user)

      # Contact with primary email only
      insert(:contact, user_id: user.id, email: "primary@example.com")

      # Contact with emails array only
      insert(:contact,
        user_id: user.id,
        email: nil,
        emails: [
          %{label: "work", email: "work@example.com"},
          %{label: "home", email: "home@example.com"}
        ]
      )

      # Contact with both primary and emails array
      insert(:contact,
        user_id: user.id,
        email: "both@example.com",
        emails: [
          %{label: "alt", email: "alt@example.com"}
        ]
      )

      # Contact with duplicate email in array
      insert(:contact,
        user_id: user.id,
        email: "duplicate@example.com",
        emails: [
          # Same as primary
          %{label: "work", email: "duplicate@example.com"},
          %{label: "alt", email: "unique@example.com"}
        ]
      )

      # Different user's contact (should not be included)
      other_user = insert(:user)
      insert(:contact, user_id: other_user.id, email: "other@example.com")

      emails = Contacts.list_all_emails(user.id)

      # Should return all unique emails for the user
      expected_emails = [
        "primary@example.com",
        "work@example.com",
        "home@example.com",
        "both@example.com",
        "alt@example.com",
        "duplicate@example.com",
        "unique@example.com"
      ]

      assert length(emails) == length(expected_emails)
      assert Enum.all?(expected_emails, &(&1 in emails))

      # Should not include other user's email
      refute "other@example.com" in emails
    end

    test "handles contacts with empty or nil email fields" do
      user = insert(:user)

      # Contact with nil email and empty emails array
      insert(:contact, user_id: user.id, email: nil, emails: [])

      # Contact with empty string email
      insert(:contact, user_id: user.id, email: "")

      # Contact with valid email
      insert(:contact, user_id: user.id, email: "valid@example.com")

      # Contact with emails array containing empty email
      insert(:contact,
        user_id: user.id,
        email: nil,
        emails: [
          %{label: "empty", email: ""},
          %{label: "valid", email: "array@example.com"}
        ]
      )

      emails = Contacts.list_all_emails(user.id)

      # Should only return non-empty emails
      assert emails == ["valid@example.com", "array@example.com"]
    end

    test "returns empty list when user has no contacts" do
      user = insert(:user)

      emails = Contacts.list_all_emails(user.id)

      assert emails == []
    end

    test "deduplicates emails correctly" do
      user = insert(:user)

      # Multiple contacts with same email
      insert(:contact, user_id: user.id, email: "same@example.com")
      insert(:contact, user_id: user.id, email: "same@example.com")

      # Contact with same email in array
      insert(:contact,
        user_id: user.id,
        email: "same@example.com",
        emails: [
          %{label: "work", email: "same@example.com"},
          %{label: "alt", email: "different@example.com"}
        ]
      )

      emails = Contacts.list_all_emails(user.id)

      # Should only return unique emails
      assert length(emails) == 2
      assert "same@example.com" in emails
      assert "different@example.com" in emails
    end
  end

  defp timestamp(days_from_now) do
    %{
      top: [],
      bottom: [],
      new_enrichments: []
    }

    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(days_from_now, :day)
    |> NaiveDateTime.truncate(:second)
  end
end
