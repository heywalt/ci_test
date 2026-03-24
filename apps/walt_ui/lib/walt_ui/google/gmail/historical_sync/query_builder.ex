defmodule WaltUi.Google.Gmail.HistoricalSync.QueryBuilder do
  @moduledoc """
  Builds Gmail search queries for historical sync operations.
  Handles contact email batching and date filtering.
  """

  @default_days_back 180

  @doc """
  Builds a Gmail query for a batch of contact emails.
  Excludes the user's own email to avoid self-correspondence.
  """
  @spec build_contact_query(list(String.t()), String.t()) :: String.t()
  def build_contact_query(email_list, user_email) do
    date_filter = build_date_filter()

    email_conditions =
      email_list
      |> Enum.reject(&(&1 == user_email))
      |> Enum.map_join(" OR ", fn email ->
        "(from:#{email} OR to:#{email})"
      end)

    "#{date_filter} AND (#{email_conditions})"
  end

  @doc """
  Builds date filter for historical sync based on configuration.
  """
  @spec build_date_filter() :: String.t()
  def build_date_filter do
    days_back = Application.get_env(:walt_ui, :historical_sync_days, @default_days_back)
    date = Date.utc_today() |> Date.add(-days_back)
    "after:#{Date.to_iso8601(date)}"
  end

  @doc """
  Gets the configured number of days to look back for historical sync.
  """
  @spec get_days_back() :: integer()
  def get_days_back do
    Application.get_env(:walt_ui, :historical_sync_days, @default_days_back)
  end
end
