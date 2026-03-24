defmodule WaltUi.Projectors.PttScoreTest do
  use WaltUi.CqrsCase

  import WaltUi.Factory
  import AssertAsync

  alias CQRS.Enrichments.Events.EnrichmentComposed
  alias CQRS.Leads.Commands, as: Cmd
  alias WaltUi.Projections.PttScore

  setup do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
    user = insert(:user, email: "test_external_accounts_#{System.unique_integer()}@example.com")
    contact = await_contact(ptt: 0, user_id: user.id)

    [event_id: contact.id, now: now, user_id: contact.user_id]
  end

  describe "PttJittered event" do
    test "creates projection record with jitter score", ctx do
      cmd = %Cmd.JitterPtt{id: ctx.event_id, score: 13, timestamp: ctx.now}
      CQRS.dispatch(cmd, consistency: :strong)

      assert %{score: 13, score_type: :jitter} = Repo.get_by(PttScore, contact_id: ctx.event_id)
    end
  end

  describe "LeadCreated event" do
    test "creates projection record if ptt is non-zero" do
      %{id: contact_id} = await_contact(ptt: 42, remote_id: UUID.uuid4())
      assert %{score: 42, score_type: :ptt} = Repo.get_by(PttScore, contact_id: contact_id)
    end

    test "noops if ptt is zero" do
      %{id: contact_id} = await_contact(ptt: 0, remote_id: UUID.uuid4())
      refute Repo.get_by(PttScore, contact_id: contact_id)
    end

    test "noops if ptt is nil" do
      %{id: contact_id} = await_contact(ptt: nil, remote_id: UUID.uuid4())
      refute Repo.get_by(PttScore, contact_id: contact_id)
    end
  end

  describe "LeadUpdated event" do
    test "creates projection record if event includes ptt", ctx do
      cmd = %Cmd.Update{
        id: ctx.event_id,
        attrs: %{ptt: 42},
        timestamp: ctx.now,
        user_id: ctx.user_id
      }

      CQRS.dispatch(cmd, consistency: :strong)

      assert %{score: 42, score_type: :ptt} = Repo.get_by(PttScore, contact_id: ctx.event_id)
    end

    test "noops if event does not include ptt", ctx do
      cmd = %Cmd.Update{
        id: ctx.event_id,
        attrs: %{first_name: "Foo"},
        timestamp: ctx.now,
        user_id: ctx.user_id
      }

      CQRS.dispatch(cmd, consistency: :strong)

      refute Repo.get_by(PttScore, contact_id: ctx.event_id)
    end
  end

  describe "LeadUnified event" do
    test "creates projection record", ctx do
      append_event(%CQRS.Leads.Events.LeadUnified{
        id: ctx.event_id,
        enrichment_id: Ecto.UUID.generate(),
        ptt: 14,
        timestamp: ctx.now
      })

      assert_async do
        assert %{score: 14, score_type: :ptt} = Repo.get_by(PttScore, contact_id: ctx.event_id)
      end
    end
  end

  describe "PttHistoryReset event" do
    test "deletes all projection records attached to contact", ctx do
      cmd = %Cmd.Update{
        id: ctx.event_id,
        attrs: %{ptt: 42},
        timestamp: ctx.now,
        user_id: ctx.user_id
      }

      CQRS.dispatch(cmd, consistency: :strong)
      CQRS.dispatch(%{cmd | attrs: %{ptt: 99}}, consistency: :strong)

      assert [_, _] = Repo.all(PttScore)

      CQRS.dispatch(%Cmd.ResetPttHistory{id: ctx.event_id, reason: "test"}, consistency: :strong)

      assert [] = Repo.all(PttScore)
    end
  end

  describe "LeadDeleted event" do
    test "deletes all projection records attached to contact", ctx do
      cmd = %Cmd.Update{
        id: ctx.event_id,
        attrs: %{ptt: 42},
        timestamp: ctx.now,
        user_id: ctx.user_id
      }

      CQRS.dispatch(cmd, consistency: :strong)
      CQRS.dispatch(%{cmd | attrs: %{ptt: 99}}, consistency: :strong)

      assert [_, _] = Repo.all(PttScore)

      CQRS.dispatch(%Cmd.Delete{id: ctx.event_id}, consistency: :strong)

      assert [] = Repo.all(PttScore)
    end
  end

  describe "EnrichmentComposed event" do
    test "creates projection record if composed_data contains ptt" do
      enrichment_id = Ecto.UUID.generate()
      contact = insert(:contact, enrichment_id: enrichment_id)

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{ptt: 85, age: 35, first_name: "John"},
        data_sources: %{ptt: :faraday, age: :faraday, first_name: :trestle},
        provider_scores: %{faraday: 90, trestle: 75},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        contact_id = contact.id

        assert %{contact_id: ^contact_id, score: 85, score_type: :ptt} =
                 Repo.get_by(PttScore, contact_id: contact_id)
      end
    end

    test "ignores events if composed_data does not contain ptt" do
      enrichment_id = Ecto.UUID.generate()
      contact = insert(:contact, enrichment_id: enrichment_id)

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{age: 35, first_name: "John"},
        data_sources: %{age: :faraday, first_name: :trestle},
        provider_scores: %{faraday: 90, trestle: 75},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        refute Repo.get_by(PttScore, contact_id: contact.id)
      end
    end

    test "handles multiple contacts linked to same enrichment" do
      enrichment_id = Ecto.UUID.generate()
      contact1 = insert(:contact, enrichment_id: enrichment_id)
      contact2 = insert(:contact, enrichment_id: enrichment_id)

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{ptt: 92},
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 95},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        contact1_id = contact1.id
        contact2_id = contact2.id
        scores = Repo.all(from p in PttScore, where: p.contact_id in [^contact1_id, ^contact2_id])
        assert length(scores) == 2
        assert Enum.all?(scores, &(&1.score == 92 && &1.score_type == :ptt))
      end
    end

    test "ignores events if no contacts are linked to enrichment" do
      enrichment_id = Ecto.UUID.generate()
      # No contact created with this enrichment_id

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{ptt: 88},
        data_sources: %{ptt: :faraday},
        provider_scores: %{faraday: 85},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(PttScore)
      end
    end

    test "ignores zero ptt values" do
      enrichment_id = Ecto.UUID.generate()
      contact = insert(:contact, enrichment_id: enrichment_id)

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{ptt: 0, age: 35},
        data_sources: %{ptt: :faraday, age: :faraday},
        provider_scores: %{faraday: 70},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        refute Repo.get_by(PttScore, contact_id: contact.id)
      end
    end

    test "ignores nil ptt values" do
      enrichment_id = Ecto.UUID.generate()
      contact = insert(:contact, enrichment_id: enrichment_id)

      event = %EnrichmentComposed{
        id: enrichment_id,
        composed_data: %{ptt: nil, age: 35},
        data_sources: %{ptt: :faraday, age: :faraday},
        provider_scores: %{faraday: 70},
        phone: "1234567890",
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        refute Repo.get_by(PttScore, contact_id: contact.id)
      end
    end
  end
end
