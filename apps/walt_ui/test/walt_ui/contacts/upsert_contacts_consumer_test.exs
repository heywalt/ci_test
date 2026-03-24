defmodule WaltUi.Contacts.UpsertContactsConsumerTest do
  use WaltUi.CqrsCase

  import AssertAsync
  import WaltUi.Factory

  alias WaltUi.Contacts.UpsertContactsConsumer, as: Consumer

  describe "handle_message/3" do
    test "messages that cannot be decoded are acked" do
      ref = Broadway.test_message(Consumer, "invalid")
      assert_receive {:ack, ^ref, [%{batcher: :noop}], []}
    end

    test "messages to update an existing contact are sent to the :updated batcher" do
      contact = await_contact(first_name: "Wade")

      message =
        contact
        |> Map.drop([
          :__meta__,
          :__struct__,
          :id,
          :events,
          :notes,
          :tags,
          :unified_contact
        ])
        |> Map.put(:first_name, "Wilson")
        |> Jason.encode!()

      ref = Broadway.test_message(Consumer, message)
      assert_receive {:ack, ^ref, [%{batcher: :updated}], []}

      assert_async do
        updated_contact = Repo.get(WaltUi.Projections.Contact, contact.id)
        assert %{first_name: "Wilson"} = updated_contact
      end
    end

    test "messages to create a new contact are sent to the :create batcher" do
      message =
        :contact
        |> params_for()
        |> Map.drop([:id, :events, :notes, :unified_contact])
        |> Jason.encode!()

      ref = Broadway.test_message(Consumer, message)
      assert_receive {:ack, ^ref, [%{batcher: :create}], []}
    end

    test "updates ignore nil values" do
      contact = await_contact(first_name: "Peter", last_name: "Parker")

      message =
        Jason.encode!(%{
          first_name: "Pete",
          last_name: nil,
          phone: contact.phone,
          remote_id: contact.remote_id,
          remote_source: contact.remote_source,
          user_id: contact.user_id
        })

      ref = Broadway.test_message(Consumer, message)
      assert_receive {:ack, ^ref, [%{batcher: :updated}], []}

      assert_async do
        updated_contact = Repo.get(WaltUi.Projections.Contact, contact.id)
        assert %{first_name: "Pete", last_name: "Parker"} = updated_contact
      end
    end
  end

  describe "handle_batch/4" do
    test ":create batch successfully creates contacts from message data" do
      user = insert(:user)

      contact_attrs = %{
        phone: "555-123-4567",
        remote_id: "google-123",
        remote_source: "google",
        user_id: user.id,
        first_name: "Miles",
        last_name: "Morales"
      }

      message = %Broadway.Message{
        data: contact_attrs,
        acknowledger: Broadway.NoopAcknowledger.init()
      }

      assert [^message] = Consumer.handle_batch(:create, [message], %{}, %{})

      assert_async do
        created_contact =
          Repo.get_by(WaltUi.Projections.Contact,
            user_id: user.id,
            remote_id: "google-123",
            remote_source: "google"
          )

        assert %{first_name: "Miles", last_name: "Morales", phone: "555-123-4567"} =
                 created_contact
      end
    end
  end
end
