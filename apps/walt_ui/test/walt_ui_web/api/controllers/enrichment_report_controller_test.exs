defmodule WaltUiWeb.Api.Controllers.EnrichmentReportControllerTest do
  use WaltUiWeb.ConnCase

  import WaltUi.Factory

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    setup do
      [user: insert(:user, email: "enrichment_report_user@example.com")]
    end

    test "returns empty lists when user has no contacts", %{conn: conn, user: user} do
      assert response =
               conn
               |> authenticate_user(user)
               |> get(~p"/api/enrichment-report")
               |> json_response(200)

      assert response["data"] == %{"top" => [], "bottom" => [], "new_enrichments" => []}
    end

    test "returns empty lists when contacts have no Move Scores", %{conn: conn, user: user} do
      insert(:contact, user_id: user.id)
      insert(:contact, user_id: user.id)
      insert(:contact, user_id: user.id)

      assert response =
               conn
               |> authenticate_user(user)
               |> get(~p"/api/enrichment-report")
               |> json_response(200)

      assert response["data"] == %{"top" => [], "bottom" => [], "new_enrichments" => []}
    end

    test "returns contacts with biggest Move Score changes", %{conn: conn, user: user} do
      # Create contacts with increasing and decreasing scores
      mike =
        insert(:contact,
          user_id: user.id,
          first_name: "Mike",
          last_name: "Peregrina"
        )

      drew = insert(:contact, user_id: user.id, first_name: "Drew", last_name: "Fravert")
      jaxon = insert(:contact, user_id: user.id, first_name: "Jaxon", last_name: "Evans")
      johnson = insert(:contact, user_id: user.id, first_name: "Johnson", last_name: "Denen")
      jd = insert(:contact, user_id: user.id, first_name: "JD", last_name: "Skinner")

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

      assert response =
               conn
               |> authenticate_user(user)
               |> get(~p"/api/enrichment-report")
               |> json_response(200)

      assert length(response["data"]["top"]) == 2
      assert length(response["data"]["bottom"]) == 2

      top_ids = Enum.map(response["data"]["top"], & &1["contact"]["id"])
      bottom_ids = Enum.map(response["data"]["bottom"], & &1["contact"]["id"])

      assert mike.id in top_ids
      assert jaxon.id in top_ids
      assert drew.id in bottom_ids
      assert johnson.id in bottom_ids
      refute jd.id in top_ids and jd.id in bottom_ids
    end

    test "does not include other users' contacts in results", %{conn: conn, user: user} do
      other_user = insert(:user, email: "other_user@example.com")

      # Other user's contact with a big score change
      other_contact =
        insert(:contact, user_id: other_user.id, first_name: "Other", last_name: "Person")

      insert(:ptt_score, contact_id: other_contact.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: other_contact.id, occurred_at: timestamp(0), score: 99)

      # Our user's contact with a score change
      my_contact =
        insert(:contact, user_id: user.id, first_name: "My", last_name: "Contact")

      insert(:ptt_score, contact_id: my_contact.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: my_contact.id, occurred_at: timestamp(0), score: 50)

      response =
        conn
        |> authenticate_user(user)
        |> get(~p"/api/enrichment-report")
        |> json_response(200)

      all_ids =
        Enum.map(response["data"]["top"], & &1["contact"]["id"]) ++
          Enum.map(response["data"]["bottom"], & &1["contact"]["id"])

      assert my_contact.id in all_ids
      refute other_contact.id in all_ids
    end

    test "handles contacts with no previous scores", %{conn: conn, user: user} do
      contact = insert(:contact, user_id: user.id, first_name: "New", last_name: "Contact")
      insert(:ptt_score, contact_id: contact.id, occurred_at: NaiveDateTime.utc_now(), score: 50)

      assert response =
               conn
               |> authenticate_user(user)
               |> get(~p"/api/enrichment-report")
               |> json_response(200)

      assert response["data"]["top"] == []
      assert response["data"]["bottom"] == []
      assert response["data"]["new_enrichments"] == []
    end

    test "returns contacts with events", ctx do
      mike =
        insert(:contact,
          user_id: ctx.user.id,
          first_name: "Mike",
          last_name: "Peregrina"
        )

      insert(:ptt_score, contact_id: mike.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: mike.id, occurred_at: timestamp(0), score: 50)
      insert(:contact_event, contact: mike)

      response =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> get(~p"/api/enrichment-report")
        |> json_response(200)

      assert [_mike] = response["data"]["top"]
    end

    test "returns contacts with notes", ctx do
      mike =
        insert(:contact,
          user_id: ctx.user.id,
          first_name: "Mike",
          last_name: "Peregrina"
        )

      insert(:ptt_score, contact_id: mike.id, occurred_at: timestamp(-7), score: 10)
      insert(:ptt_score, contact_id: mike.id, occurred_at: timestamp(0), score: 50)
      insert(:note, contact: mike)

      response =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> get(~p"/api/enrichment-report")
        |> json_response(200)

      assert [_mike] = response["data"]["top"]
    end
  end

  defp timestamp(days_from_now) do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.add(days_from_now, :day)
    |> NaiveDateTime.truncate(:second)
  end
end
