defmodule WaltUiWeb.Api.Controllers.ContactsControllerTest do
  use WaltUiWeb.ConnCase

  import WaltUi.Factory
  import WaltUi.Helpers

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "GET /api/contacts" do
    setup do
      # random contacts not attached to user under test
      insert_list(5, :contact)
      [user: insert(:user)]
    end

    test "returns list of the user's contacts", ctx do
      insert_list(3, :contact, user_id: ctx.user.id)

      data =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> get(~p"/api/contacts")
        |> json_response(200)
        |> Map.get("data")

      assert length(data) == 3
    end

    test "paginates 100 contacts at a time by default", ctx do
      insert_list(101, :contact, user_id: ctx.user.id)

      data =
        ctx.conn
        |> authenticate_user(ctx.user)
        |> get(~p"/api/contacts")
        |> json_response(200)
        |> Map.get("data")

      assert length(data) == 100
    end

    test "returns no metadata if contact not unified", ctx do
      %{id: contact_id} = insert(:contact, user_id: ctx.user.id, unified_contact: nil)

      assert [%{"id" => ^contact_id, "attributes" => %{"contact_metadata" => nil}}] =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/contacts")
               |> json_response(200)
               |> Map.get("data")
    end

    test "returns no metadata if contact unenriched", ctx do
      %{id: contact_id} = insert(:contact, user_id: ctx.user.id)

      assert [%{"id" => ^contact_id, "attributes" => %{"contact_metadata" => nil}}] =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/contacts")
               |> json_response(200)
               |> Map.get("data")
    end

    test "returns Gravatar and Jitter enrichments", ctx do
      gravatar = insert(:gravatar, url: "https://example.com/img.jpg")
      _jitter = insert(:jitter, id: gravatar.id, ptt: 13)

      %{id: contact_id} =
        insert(:contact,
          avatar: nil,
          enrichment_id: gravatar.id,
          first_name: "Wade",
          last_name: "Wilson",
          ptt: 42,
          user_id: ctx.user.id
        )

      assert [
               %{
                 "id" => ^contact_id,
                 "attributes" => %{"avatar" => "https://example.com/img.jpg", "ptt" => 13}
               }
             ] =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/contacts")
               |> json_response(200)
               |> Map.get("data")
    end

    test "returns jittered Move Score", ctx do
      jitter = insert(:jitter, ptt: 44)

      %{id: contact_id} =
        insert(:contact, enrichment_id: jitter.id, ptt: 42, user_id: ctx.user.id)

      assert [%{"id" => ^contact_id, "attributes" => %{"ptt" => 44}}] =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/contacts")
               |> json_response(200)
               |> Map.get("data")
    end

    test "returns tier field for freemium users", ctx do
      free_user = insert(:user, tier: :freemium)

      # Unenriched contact - no enrichment data, should be premium (accessible)
      %{id: unenriched_contact} =
        insert(:contact,
          phone: "5555551111",
          ptt: 55,
          user_id: free_user.id
        )

      # Enriched but not showcased contact - should be freemium (locked)
      enrichment = insert(:enrichment)

      %{id: enriched_not_showcased} =
        insert(:contact,
          phone: "5555551222",
          ptt: 55,
          enrichment_id: enrichment.id,
          user_id: free_user.id
        )

      # Enriched and showcased contact - should be premium (unlocked)
      enrichment2 = insert(:enrichment)

      %{id: enriched_showcased} =
        insert(:contact,
          phone: "5555551333",
          ptt: 55,
          enrichment_id: enrichment2.id,
          user_id: free_user.id
        )

      insert(:contact_showcase, contact_id: enriched_showcased, user_id: free_user.id)

      assert freemium_contacts =
               ctx.conn
               |> authenticate_user(free_user)
               |> get(~p"/api/contacts")
               |> json_response(200)
               |> Map.get("data")

      # Unenriched contact should be premium (accessible)
      assert %{"attributes" => %{"tier" => "premium"}} =
               Enum.find(freemium_contacts, &(&1["id"] == unenriched_contact))

      # Enriched but not showcased should be freemium (locked)
      assert %{"attributes" => %{"tier" => "freemium"}} =
               Enum.find(freemium_contacts, &(&1["id"] == enriched_not_showcased))

      # Enriched and showcased should be premium (unlocked)
      assert %{"attributes" => %{"tier" => "premium"}} =
               Enum.find(freemium_contacts, &(&1["id"] == enriched_showcased))
    end

    test "returns tier field for premium users", ctx do
      prem_user = insert(:user, tier: :premium)

      %{id: not_showcased_premium} =
        insert(:contact,
          phone: "5555551234",
          ptt: 42,
          user_id: prem_user.id
        )

      %{id: showcased_premium} =
        insert(:contact,
          phone: "5555551234",
          ptt: 42,
          user_id: prem_user.id
        )

      insert(:contact_showcase, contact_id: showcased_premium, user_id: prem_user.id)

      assert premium_contacts =
               ctx.conn
               |> authenticate_user(prem_user)
               |> get(~p"/api/contacts")
               |> json_response(200)
               |> Map.get("data")

      assert %{"attributes" => %{"tier" => "premium"}} =
               Enum.find(premium_contacts, &(&1["id"] == not_showcased_premium))

      assert %{"attributes" => %{"tier" => "premium"}} =
               Enum.find(premium_contacts, &(&1["id"] == showcased_premium))
    end

    test "returns contact metadata", ctx do
      enr = insert(:enrichment)

      %{id: contact_id} =
        insert(:contact,
          first_name: "Wade",
          last_name: "Wilson",
          email: "wade@deadpool.net",
          enrichment_id: enr.id,
          phone: "8015551234",
          ptt: 42,
          standard_phone: "8015551234",
          user_id: ctx.user.id
        )

      assert [
               %{
                 "id" => ^contact_id,
                 "type" => "contacts",
                 "attributes" => %{
                   "address" => %{},
                   "birthday" => nil,
                   "budget_size" => nil,
                   "contact_metadata" => %{
                     "financial" => %{
                       "affluency" => "true",
                       "credit_rating" => nil,
                       "home_equity_loan_amount" => "$0-$50k",
                       "home_equity_loan_date" => "9/10/2018",
                       "homeowner_status" => "Probable Owner",
                       "household_income" => "$70k+",
                       "income_change_date" => "2/14/2010",
                       "latest_mortgage_amount" => "$0-$50k",
                       "latest_mortgage_date" => "7/5/2016",
                       "latest_mortgage_interest_rate" => "3-4%",
                       "liquid_resources" => "$25k - $49k",
                       "mortgage_liability" => "$50k-$100k",
                       "net_worth" => "$50k-$100k",
                       "percent_equity" => "60%-70%"
                     },
                     "home" => %{
                       "average_commute_time" => "10-20",
                       "basement_area" => "13326",
                       "garage_spaces" => "0-2",
                       "has_basement" => true,
                       "has_pool" => true,
                       "homeowner_status" => "Probable Owner",
                       "length_of_residence" => "15-20",
                       "living_area" => "26296",
                       "lot_area" => "1.86",
                       "lot_size_in_acres" => "1-2",
                       "number_of_bathrooms" => "3-4",
                       "number_of_bedrooms" => "3-4",
                       "probability_to_have_hot_tub" => "90%-100%",
                       "property_type" => "APARTMENT",
                       "target_home_market_value" => "$1M+",
                       "year_built" => "1994",
                       "zoning_type" => "RR"
                     },
                     "main" => %{
                       "age" => "65+",
                       "date_newly_married" => "5/1/2011",
                       "date_newly_single" => "8/17/2023",
                       "date_of_birth" => "8/17/1958",
                       "education" => "Completed College",
                       "full_name" => "Peter Parker",
                       "marital_status" => "Married",
                       "occupation" => "Business Owner"
                     },
                     "personal_info" => %{
                       "date_empty_nester" => "1/1/2008",
                       "date_retired" => "2/13/2010",
                       "first_child_birthdate" => "4/4/1991",
                       "has_children_in_household" => false,
                       "has_pet" => true,
                       "interest_in_grandchildren" => false,
                       "is_active_on_social_media" => true,
                       "is_facebook_user" => true,
                       "is_instagram_user" => false,
                       "is_twitter_user" => true,
                       "likes_travel" => false,
                       "number_of_children" => "0-2",
                       "vehicle_make" => "Ford",
                       "vehicle_model" => "Focus",
                       "vehicle_year" => "2004"
                     }
                   },
                   "email" => "wade@deadpool.net",
                   "events" => nil,
                   "first_name" => "Wade",
                   "has_broker" => nil,
                   "has_financing" => false,
                   "is_favorite" => false,
                   "is_highlighted" => false,
                   "last_name" => "Wilson",
                   "phone" => "8015551234",
                   "ptt" => 42,
                   "search" => nil
                 }
               }
             ] =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/contacts")
               |> json_response(200)
               |> Map.get("data")
    end
  end

  describe "GET /api/contacts/:id" do
    test "returns error for invalid ID format", %{conn: conn} do
      user = WaltUi.AccountFixtures.user_fixture()

      conn
      |> authenticate_user(user)
      |> get(~p"/api/contacts/1")
      |> json_response(400)
    end
  end

  describe "POST /api/contacts" do
    setup do
      [user: insert(:user)]
    end

    test "renders the created contact", ctx do
      payload = %{
        first_name: "Test",
        last_name: "McTest",
        phone: "5551239999",
        remote_id: UUID.uuid4(),
        remote_source: "test",
        user_id: ctx.user.id
      }

      assert %{"data" => %{"attributes" => %{"phone" => "5551239999"}}} =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> post(~p"/api/contacts", payload)
               |> json_response(200)
    end
  end

  describe "PUT /api/contacts/:id" do
    setup do
      user = insert(:user)
      contact = await_contact(remote_id: UUID.uuid4(), phone: "5551231234", user_id: user.id)

      [contact: contact, user: user]
    end

    test "returns updated state", ctx do
      now = NaiveDateTime.to_iso8601(NaiveDateTime.utc_now())
      payload = %{is_favorite: true, inserted_at: now, updated_at: now}

      assert %{"data" => %{"attributes" => %{"is_favorite" => true}}} =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> put(~p"/api/contacts/#{ctx.contact.id}", payload)
               |> json_response(200)
    end
  end

  describe "GET /api/contacts/:id/ptt" do
    setup do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      [contact: contact, user: user]
    end

    test "returns empty list for contact with no ptt history", ctx do
      assert %{"data" => []} =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/contacts/#{ctx.contact.id}/ptt")
               |> json_response(200)
    end

    test "returns Move Scores in reverse chronological order", ctx do
      months_ago = Date.utc_today() |> Date.add(-30 * 4) |> NaiveDateTime.new!(~T[00:00:00])
      insert(:ptt_score, contact_id: ctx.contact.id, occurred_at: months_ago)

      assert %{"data" => [a, b, c | _] = scores} =
               ctx.conn
               |> authenticate_user(ctx.user)
               |> get(~p"/api/contacts/#{ctx.contact.id}/ptt")
               |> json_response(200)

      assert length(scores) == 12

      a_ts = a |> Map.get("occurred_at") |> NaiveDateTime.from_iso8601!()
      b_ts = b |> Map.get("occurred_at") |> NaiveDateTime.from_iso8601!()
      c_ts = c |> Map.get("occurred_at") |> NaiveDateTime.from_iso8601!()

      # in order
      assert NaiveDateTime.compare(a_ts, b_ts) == :gt
      assert NaiveDateTime.compare(b_ts, c_ts) == :gt

      # separated by a week
      assert NaiveDateTime.diff(a_ts, b_ts, :day) == 7
      assert NaiveDateTime.diff(a_ts, c_ts, :day) == 14

      # normalized to sunday
      assert a_ts |> NaiveDateTime.to_date() |> Date.day_of_week() == 7
    end
  end
end
