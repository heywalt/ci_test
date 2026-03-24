defmodule WaltUi.Projectors.JitterTest do
  use WaltUi.CqrsCase

  import AssertAsync
  import WaltUi.Factory

  alias CQRS.Enrichments.Events.EnrichmentReset
  alias CQRS.Enrichments.Events.Jittered
  alias WaltUi.Projections.Jitter

  describe "Jittered event" do
    test "projects new jitter data" do
      event_id = Ecto.UUID.generate()
      append_event(%Jittered{id: event_id, score: 42, timestamp: NaiveDateTime.utc_now()})

      assert_async do
        assert [%{id: ^event_id, ptt: 42}] = Repo.all(Jitter)
      end
    end

    test "updates existing jitter data" do
      record = insert(:jitter, ptt: 13)
      append_event(%Jittered{id: record.id, score: 42, timestamp: NaiveDateTime.utc_now()})

      assert_async do
        assert %{ptt: 42} = Repo.reload(record)
      end
    end
  end

  describe "EnrichmentReset event" do
    test "deletes jitter record for existing enrichment" do
      jitter = insert(:jitter, ptt: 42)

      event = %EnrichmentReset{
        id: jitter.id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        assert [] = Repo.all(Jitter)
      end
    end

    test "handles reset for non-existent enrichment_id" do
      # Create a jitter record to ensure database isn't empty
      existing_jitter = insert(:jitter, ptt: 13)
      non_existent_id = Ecto.UUID.generate()

      event = %EnrichmentReset{
        id: non_existent_id,
        timestamp: NaiveDateTime.utc_now()
      }

      append_event(event)

      assert_async do
        # Existing jitter should remain unchanged
        jitters = Repo.all(Jitter)
        assert [%{id: id}] = jitters
        assert id == existing_jitter.id
      end
    end
  end
end
