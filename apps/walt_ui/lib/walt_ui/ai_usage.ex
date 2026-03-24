defmodule WaltUi.AIUsage do
  @moduledoc """
  Context for tracking and managing AI token usage.
  """

  import Ecto.Query
  alias WaltUi.Conversations.Conversation
  alias WaltUi.Conversations.ConversationMessage

  @doc """
  Gets the total token usage for a user in a specific month.

  Returns the sum of all input and output tokens from conversation messages
  created during the specified month.

  ## Parameters
    * `user_id` - The user's ID
    * `date` - The date within the month to check (defaults to today)

  ## Examples

      iex> get_monthly_usage(user_id)
      150000

      iex> get_monthly_usage(user_id, ~D[2025-09-15])
      250000
  """
  def get_monthly_usage(user_id, date \\ Date.utc_today()) do
    {start_of_month, start_of_next_month} = month_bounds(date)

    query =
      from cm in ConversationMessage,
        join: c in Conversation,
        on: cm.conversation_id == c.id,
        where: c.user_id == ^user_id,
        where: cm.inserted_at >= ^start_of_month,
        where: cm.inserted_at < ^start_of_next_month,
        select:
          coalesce(sum(cm.input_tokens), 0) +
            coalesce(sum(cm.output_tokens), 0)

    Repo.one(query) || 0
  end

  @doc """
  Checks if a user is within their monthly token limit.

  Returns `true` if the user's current month usage is at or below the configured
  monthly limit, `false` otherwise.

  ## Parameters
    * `user_id` - The user's ID

  ## Examples

      iex> within_limit?(user_id)
      true

      iex> within_limit?(over_limit_user_id)
      false
  """
  def within_limit?(user_id) do
    monthly_limit = get_monthly_limit()
    current_usage = get_monthly_usage(user_id)

    current_usage <= monthly_limit
  end

  @doc """
  Gets the configured monthly token limit from application config.

  ## Examples

      iex> get_monthly_limit()
      1_000_000
  """
  def get_monthly_limit do
    Application.get_env(:walt_ui, :ai_usage)[:monthly_token_limit] || 1_000_000
  end

  # Private functions

  defp month_bounds(date) do
    start_of_month = Date.beginning_of_month(date) |> DateTime.new!(~T[00:00:00])

    start_of_next_month =
      date
      |> Date.beginning_of_month()
      |> Date.add(Date.days_in_month(date))
      |> DateTime.new!(~T[00:00:00])

    {start_of_month, start_of_next_month}
  end
end
