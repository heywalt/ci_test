defmodule WaltUi.Projectors.ContactShowcaseTest do
  use WaltUi.CqrsCase

  import AssertAsync
  import WaltUi.Factory

  alias CQRS.Enrichments.Events.EnrichmentReset
  alias WaltUi.Projections.ContactShowcase

  setup do
    user = insert(:user)
    contact = await_contact(user_id: user.id)

    [contact: contact, user: user]
  end

  describe "LeadUpdated event" do
    test "ignores event that does not include an enrichment type", ctx do
      CQRS.update_contact(ctx.contact, %{first_name: "A"}, consistency: :strong)
      assert [] = Repo.all(ContactShowcase)
    end

    test "ignores event if 150 contacts already showcased with best enrichment type", ctx do
      insert_list(150, :contact_showcase, enrichment_type: :best, user_id: ctx.user.id)
      CQRS.update_contact(ctx.contact, %{enrichment_type: :best}, consistency: :strong)
      refute Repo.get_by(ContactShowcase, contact_id: ctx.contact.id)
    end

    test "updates enrichment type if contact already showcased with different type", ctx do
      insert(:contact_showcase, contact_id: ctx.contact.id, user_id: ctx.user.id)
      CQRS.update_contact(ctx.contact, %{enrichment_type: :best}, consistency: :strong)
      assert %{enrichment_type: :best} = Repo.get_by(ContactShowcase, contact_id: ctx.contact.id)
    end

    test "adds showcase if less than 150 contacts showcased", ctx do
      insert_list(149, :contact_showcase, user_id: ctx.user.id, enrichment_type: :best)
      CQRS.update_contact(ctx.contact, %{enrichment_type: :lesser}, consistency: :strong)

      assert_async do
        assert %{enrichment_type: :lesser} =
                 Repo.get_by(ContactShowcase, contact_id: ctx.contact.id)
      end

      assert showcased?(ctx.contact)
    end

    test "swaps lesser enrichment for best enrichment", ctx do
      lesser = await_contact(user_id: ctx.user.id)
      old_sc = insert(:contact_showcase, contact_id: lesser.id, user_id: ctx.user.id)
      insert_list(149, :contact_showcase, user_id: ctx.user.id, enrichment_type: :best)

      CQRS.update_contact(ctx.contact, %{enrichment_type: :best}, consistency: :strong)

      assert_async do
        assert Repo.aggregate(ContactShowcase, :count) == 150
        refute Repo.reload(old_sc)

        assert %{enrichment_type: :best} =
                 Repo.get_by(ContactShowcase, contact_id: ctx.contact.id)
      end

      refute showcased?(lesser)
      assert showcased?(ctx.contact)
    end
  end

  describe "LeadDeleted event" do
    test "deletes showcase record", ctx do
      insert(:contact_showcase, contact_id: ctx.contact.id, user_id: ctx.user.id)
      CQRS.delete_contact(ctx.contact.id)

      assert_async do
        assert [] = Repo.all(ContactShowcase, consistency: :strong)
      end
    end
  end

  describe "EnrichmentReset event" do
    test "deletes ContactShowcase records when contacts still have enrichment_id", ctx do
      enrichment_id = Ecto.UUID.generate()

      contact1 = insert(:contact, enrichment_id: enrichment_id, user_id: ctx.user.id)
      contact2 = insert(:contact, enrichment_id: enrichment_id, user_id: ctx.user.id)
      other_contact = insert(:contact, enrichment_id: Ecto.UUID.generate(), user_id: ctx.user.id)

      showcase1 = insert(:contact_showcase, contact_id: contact1.id, user_id: ctx.user.id)
      showcase2 = insert(:contact_showcase, contact_id: contact2.id, user_id: ctx.user.id)

      other_showcase =
        insert(:contact_showcase, contact_id: other_contact.id, user_id: ctx.user.id)

      event = %EnrichmentReset{
        id: enrichment_id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        # ContactShowcase records for contacts with matching enrichment_id should be deleted
        refute Repo.reload(showcase1)
        refute Repo.reload(showcase2)

        # ContactShowcase records for contacts with different enrichment_id should remain
        assert Repo.reload(other_showcase)
      end
    end

    test "deletes ContactShowcase records when contacts have NULL enrichment_id", ctx do
      enrichment_id = Ecto.UUID.generate()

      # Simulating post-reset state
      contact1 = insert(:contact, enrichment_id: nil, user_id: ctx.user.id)
      # Simulating post-reset state
      contact2 = insert(:contact, enrichment_id: nil, user_id: ctx.user.id)
      other_contact = insert(:contact, enrichment_id: Ecto.UUID.generate(), user_id: ctx.user.id)

      showcase1 = insert(:contact_showcase, contact_id: contact1.id, user_id: ctx.user.id)
      showcase2 = insert(:contact_showcase, contact_id: contact2.id, user_id: ctx.user.id)

      other_showcase =
        insert(:contact_showcase, contact_id: other_contact.id, user_id: ctx.user.id)

      event = %EnrichmentReset{
        id: enrichment_id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        # ContactShowcase records for contacts with NULL enrichment_id should be deleted
        refute Repo.reload(showcase1)
        refute Repo.reload(showcase2)

        # ContactShowcase records for contacts with specific enrichment_id should remain
        assert Repo.reload(other_showcase)
      end
    end

    test "handles reset for enrichment with no ContactShowcase records", ctx do
      enrichment_id = Ecto.UUID.generate()

      # Create some contacts but no ContactShowcase records
      insert(:contact, enrichment_id: enrichment_id, user_id: ctx.user.id)
      insert(:contact, enrichment_id: enrichment_id, user_id: ctx.user.id)

      # Create unrelated ContactShowcase record
      other_contact = insert(:contact, enrichment_id: Ecto.UUID.generate(), user_id: ctx.user.id)

      other_showcase =
        insert(:contact_showcase, contact_id: other_contact.id, user_id: ctx.user.id)

      event = %EnrichmentReset{
        id: enrichment_id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        # Should be a no-op - no ContactShowcase records to delete
        # Other unrelated ContactShowcase should remain
        assert Repo.reload(other_showcase)
        assert Repo.aggregate(ContactShowcase, :count) == 1
      end
    end
  end

  defp showcased?(contact) do
    contact.user_id
    |> WaltUi.Contacts.simple_user_contacts_query()
    |> Ecto.Query.where([con], con.id == ^contact.id)
    |> Repo.one()
    |> case do
      nil -> false
      con -> con.is_showcased
    end
  end
end
