defmodule WaltUi.Projectors.ContactCreationTest do
  use WaltUi.CqrsCase

  import WaltUi.Factory

  alias CQRS.Leads.Commands, as: Cmd
  alias WaltUi.Projections.ContactCreation

  setup do
    [user_id: insert(:user).id]
  end

  describe "LeadCreated event" do
    test "creates projection of type :create", %{user_id: user_id} do
      cmd = %Cmd.Create{
        id: Ecto.UUID.generate(),
        phone: "5551235555",
        timestamp: NaiveDateTime.utc_now(),
        user_id: user_id
      }

      CQRS.dispatch(cmd, consistency: :strong)

      assert [%{type: :create, user_id: ^user_id}] = Repo.all(ContactCreation)
    end

    test "when timestamp is iso8601", %{user_id: user_id} do
      cmd = %Cmd.Create{
        id: Ecto.UUID.generate(),
        phone: "5551235555",
        timestamp: NaiveDateTime.to_iso8601(NaiveDateTime.utc_now()),
        user_id: user_id
      }

      CQRS.dispatch(cmd, consistency: :strong)

      assert [%{type: :create, user_id: ^user_id}] = Repo.all(ContactCreation)
    end
  end

  describe "LeadDeleted event" do
    setup ctx do
      [contact: await_contact(user_id: ctx.user_id)]
    end

    test "creates projection of type :delete", ctx do
      refute Repo.get_by(ContactCreation, type: :delete, user_id: ctx.user_id)

      cmd = %Cmd.Delete{id: ctx.contact.id}
      CQRS.dispatch(cmd, consistency: :strong)

      assert %ContactCreation{} =
               Repo.get_by(ContactCreation, type: :delete, user_id: ctx.user_id)
    end
  end
end
