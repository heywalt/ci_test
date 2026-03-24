defmodule WaltUi.Contacts.CreateContactsConsumerTest do
  use Repo.DataCase

  alias WaltUi.Contacts.CreateContactsConsumer, as: Consumer

  describe "handle_message/3" do
    test "message that cannot become decoded reaches :noop batcher" do
      ref = Broadway.test_message(Consumer, "invalid")
      assert_receive {:ack, ^ref, [%{batcher: :noop}], []}
    end

    test "valid message reaches :bulk_create batcher" do
      message =
        Jason.encode!(%{
          id: Ecto.UUID.generate(),
          phone: "5555555555",
          user_id: Ecto.UUID.generate()
        })

      ref = Broadway.test_message(Consumer, message)
      assert_receive {:ack, ^ref, [%{batcher: :bulk_create}], []}
    end

    test "valid message data formatted for bulk insert" do
      contact_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      message = Jason.encode!(%{id: contact_id, phone: "5555555555", user_id: user_id})

      ref = Broadway.test_message(Consumer, message)
      assert_receive {:ack, ^ref, [%{data: data}], []}

      assert %{phone: "5555555555", user_id: ^user_id} = data
    end
  end
end
