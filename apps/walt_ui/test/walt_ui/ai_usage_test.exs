defmodule WaltUi.AIUsageTest do
  use WaltUi.CqrsCase

  import WaltUi.Factory

  alias WaltUi.AIUsage
  alias WaltUi.Conversations
  alias WaltUi.Conversations.Conversation
  alias WaltUi.Conversations.ConversationMessage

  setup do
    user = insert(:user)
    [user: user]
  end

  describe "get_monthly_usage/2" do
    test "returns 0 when user has no conversations", ctx do
      assert 0 == AIUsage.get_monthly_usage(ctx.user.id)
    end

    test "returns total tokens for current month", ctx do
      # Create conversation with messages in current month
      conversation =
        Repo.insert!(%Conversation{
          user_id: ctx.user.id,
          title: "Test conversation"
        })

      {:ok, _msg1} =
        Conversations.add_message(
          conversation.id,
          "user",
          "Hello",
          100,
          50
        )

      {:ok, _msg2} =
        Conversations.add_message(
          conversation.id,
          "model",
          "Hi there!",
          75,
          25
        )

      # Total should be 100 + 50 + 75 + 25 = 250
      assert 250 == AIUsage.get_monthly_usage(ctx.user.id)
    end

    test "only counts messages from current month", ctx do
      conversation =
        Repo.insert!(%Conversation{
          user_id: ctx.user.id,
          title: "Test conversation"
        })

      # Add a message in current month
      {:ok, _current_msg} =
        Conversations.add_message(
          conversation.id,
          "user",
          "Current month",
          100,
          50
        )

      # Simulate an old message from last month by updating inserted_at
      last_month =
        DateTime.utc_now()
        |> DateTime.add(-35, :day)
        |> DateTime.to_naive()
        |> NaiveDateTime.truncate(:second)

      Repo.insert!(%ConversationMessage{
        conversation_id: conversation.id,
        role: :user,
        content: "Last month",
        input_tokens: 200,
        output_tokens: 100,
        inserted_at: last_month
      })

      # Should only count current month's message (100 + 50 = 150)
      assert 150 == AIUsage.get_monthly_usage(ctx.user.id)
    end

    test "counts messages from multiple conversations", ctx do
      conv1 = Repo.insert!(%Conversation{user_id: ctx.user.id, title: "Conv 1"})
      conv2 = Repo.insert!(%Conversation{user_id: ctx.user.id, title: "Conv 2"})

      {:ok, _msg1} = Conversations.add_message(conv1.id, "user", "Hello", 100, 50)
      {:ok, _msg2} = Conversations.add_message(conv2.id, "user", "Hi", 75, 25)

      # Total: 100 + 50 + 75 + 25 = 250
      assert 250 == AIUsage.get_monthly_usage(ctx.user.id)
    end

    test "only counts messages for specified user", ctx do
      other_user = insert(:user)

      conv1 = Repo.insert!(%Conversation{user_id: ctx.user.id, title: "User 1 Conv"})
      conv2 = Repo.insert!(%Conversation{user_id: other_user.id, title: "User 2 Conv"})

      {:ok, _msg1} = Conversations.add_message(conv1.id, "user", "Hello", 100, 50)
      {:ok, _msg2} = Conversations.add_message(conv2.id, "user", "Hi", 200, 100)

      # Should only count user 1's messages
      assert 150 == AIUsage.get_monthly_usage(ctx.user.id)
      # Should only count user 2's messages
      assert 300 == AIUsage.get_monthly_usage(other_user.id)
    end

    test "handles nil token values", ctx do
      conversation =
        Repo.insert!(%Conversation{
          user_id: ctx.user.id,
          title: "Test conversation"
        })

      # Manually insert message with nil tokens
      Repo.insert!(%ConversationMessage{
        conversation_id: conversation.id,
        role: :user,
        content: "No tokens tracked",
        input_tokens: nil,
        output_tokens: nil,
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      })

      {:ok, _msg_with_tokens} =
        Conversations.add_message(
          conversation.id,
          "model",
          "Response",
          50,
          25
        )

      # Should handle nil values and only count non-nil tokens
      assert 75 == AIUsage.get_monthly_usage(ctx.user.id)
    end

    test "can get usage for specific month", ctx do
      conversation =
        Repo.insert!(%Conversation{
          user_id: ctx.user.id,
          title: "Test conversation"
        })

      # Add message in current month
      {:ok, _current} = Conversations.add_message(conversation.id, "user", "Current", 100, 50)

      # Add message from last month
      last_month_date = Date.utc_today() |> Date.add(-35)
      last_month = NaiveDateTime.new!(last_month_date, ~T[12:00:00])

      Repo.insert!(%ConversationMessage{
        conversation_id: conversation.id,
        role: :user,
        content: "Last month",
        input_tokens: 200,
        output_tokens: 100,
        inserted_at: last_month
      })

      # Current month should be 150
      assert 150 == AIUsage.get_monthly_usage(ctx.user.id, Date.utc_today())

      # Last month should be 300
      assert 300 == AIUsage.get_monthly_usage(ctx.user.id, last_month_date)
    end
  end

  describe "within_limit?/1" do
    test "returns true when under limit", ctx do
      conversation =
        Repo.insert!(%Conversation{
          user_id: ctx.user.id,
          title: "Test conversation"
        })

      # Add small amount of tokens (well under 1M limit)
      {:ok, _msg} = Conversations.add_message(conversation.id, "user", "Hello", 100, 50)

      assert true == AIUsage.within_limit?(ctx.user.id)
    end

    test "returns true when exactly at limit", ctx do
      conversation =
        Repo.insert!(%Conversation{
          user_id: ctx.user.id,
          title: "Test conversation"
        })

      # Add exactly 1M tokens
      {:ok, _msg} =
        Conversations.add_message(conversation.id, "user", "Hello", 500_000, 500_000)

      assert true == AIUsage.within_limit?(ctx.user.id)
    end

    test "returns false when over limit", ctx do
      conversation =
        Repo.insert!(%Conversation{
          user_id: ctx.user.id,
          title: "Test conversation"
        })

      # Add more than 1M tokens (1,000,001 total)
      {:ok, _msg} =
        Conversations.add_message(conversation.id, "user", "Hello", 500_000, 500_001)

      assert false == AIUsage.within_limit?(ctx.user.id)
    end

    test "returns true when user has no messages", ctx do
      assert true == AIUsage.within_limit?(ctx.user.id)
    end
  end
end
