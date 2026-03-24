defmodule WaltUi.Projectors.GravatarTest do
  use WaltUi.CqrsCase, async: false

  import AssertAsync
  import Mox

  alias CQRS.Enrichments.Events.EnrichedWithEndato
  alias WaltUi.Enrichment.GravatarMock
  alias WaltUi.Projections.Gravatar

  setup [:set_mox_global, :verify_on_exit!]

  setup do
    Application.put_env(:walt_ui, WaltUi.Enrichment.Gravatar,
      client: WaltUi.Enrichment.GravatarMock
    )

    on_exit(fn ->
      Application.put_env(:walt_ui, WaltUi.Enrichment.Gravatar,
        client: WaltUi.Enrichment.Gravatar.Dummy
      )
    end)
  end

  describe "EnrichedWithEndato event" do
    test "projects the first valid email" do
      event_id = Ecto.UUID.generate()

      expect(GravatarMock, :get_avatar, fn _ -> {:ok, %{status: 404, url: "nope"}} end)
      expect(GravatarMock, :get_avatar, fn _ -> {:ok, %{status: 200, url: "test"}} end)
      expect(GravatarMock, :get_avatar, fn _ -> {:ok, %{status: 200, url: "ignore"}} end)

      append_event(%EnrichedWithEndato{
        id: event_id,
        addresses: [],
        emails: ["one@foo.org", "two@foo.org", "three@foo.org"],
        first_name: "John",
        last_name: "Doe",
        phone: "5551231234",
        timestamp: NaiveDateTime.utc_now()
      })

      assert_async do
        assert %{email: "two@foo.org", url: "test"} = Repo.get(Gravatar, event_id)
      end
    end
  end
end
