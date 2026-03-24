defmodule WaltUi.ExternalAccounts do
  @moduledoc """
  Context module used to interact with external accounts.

  External Accounts we integrate with:
  - Google (Gmail)
  """

  require Logger

  alias WaltUi.Account
  alias WaltUi.Error
  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.Google.Gmail
  alias WaltUi.Google.Gmail.HistoricalEmailSyncJob

  @spec fetch(Ecto.UUID.t()) :: {:ok, ExternalAccount.t()} | Error.t()
  def fetch(id) do
    case get(id) do
      nil ->
        Error.new("ExternalAccount not found",
          reason_atom: :not_found,
          details: %{external_account_id: id}
        )

      ea ->
        {:ok, ea}
    end
  end

  @spec get(Ecto.UUID.t()) :: ExternalAccount.t() | nil
  def get(id), do: Repo.get(ExternalAccount, id)

  @spec find_by_provider([ExternalAccount.t()], atom) ::
          {:ok, ExternalAccount.t()} | {:error, :not_found}
  def find_by_provider(eas, provider) do
    eas
    |> Enum.find(fn ea -> ea.provider == provider end)
    |> case do
      nil -> {:error, :not_found}
      ea -> {:ok, ea}
    end
  end

  @spec create_from_mobile(map) :: {:ok, ExternalAccount.t()} | {:error, Ecto.Changeset.t()}
  def create_from_mobile(attrs) do
    expires_at_usec = DateTime.from_unix!(attrs["expires_in"], :second)

    external_account_or_changeset =
      case ExternalAccounts.for_user_id(attrs["user_id"], attrs["provider"]) do
        nil ->
          attrs
          |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
          |> Map.put(:expires_at, expires_at_usec)
          |> create()

        ea ->
          ExternalAccounts.update(ea, attrs)
      end

    # Because the mobile app doesn't get the email address back, we need to go
    # get it after the external account has been created. Now we need to consider
    # what needs to be done if the provider isn't Google.
    update_external_account_with_email(external_account_or_changeset)

    external_account_or_changeset
  end

  defp update_external_account_with_email({:ok, %ExternalAccount{provider: :google} = ea}) do
    Task.Supervisor.async_nolink(WaltUi.TaskSupervisor, fn ->
      ea
      |> Gmail.get_profile()
      |> case do
        {:ok, profile} ->
          ExternalAccounts.update(ea, %{email: profile["emailAddress"]})

        {:error, error} ->
          Logger.error("Error getting profile: #{inspect(error)}")
      end
    end)
  end

  # If it's an error, we don't care; if it's a non-google provider, we also don't care.
  defp update_external_account_with_email(_), do: :ok

  @spec create_from_web(Account.User.t(), map, String.t()) ::
          {:ok, ExternalAccount.t()} | {:error, Ecto.Changeset.t()}
  def create_from_web(user, auth_payload, provider) do
    case ExternalAccounts.for_user_id(user.id, provider) do
      nil ->
        user
        |> format_attrs(auth_payload)
        |> Map.put(:token_source, :web)
        |> create()

      ea ->
        attrs = format_attrs(user, auth_payload)
        update(ea, attrs)
    end
  end

  @spec create(map) :: {:ok, ExternalAccount.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs) do
    %ExternalAccount{}
    |> ExternalAccount.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, ea} ->
        # Sets the Gmail history ID for the account so the next time we sync,
        # we have someplace to start.
        Gmail.set_initial_history_id(ea)
        maybe_sync_calendars(ea)
        maybe_enqueue_historical_email_sync(ea)

        {:ok, ea}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @spec update(ExternalAccount.t(), map) ::
          {:ok, ExternalAccount.t()} | {:error, Ecto.Changeset.t()}
  def update(external_account, attrs) do
    external_account
    |> ExternalAccount.changeset(attrs)
    |> Repo.update()
  end

  @spec delete(ExternalAccount.t()) :: ExternalAccount.t() | no_return()
  def delete(external_account), do: Repo.delete(external_account)

  @spec for_user(Account.User.t(), atom) :: ExternalAccount.t() | nil
  def for_user(_user, nil), do: nil

  def for_user(user, provider) do
    Repo.get_by(ExternalAccount, user_id: user.id, provider: provider)
  end

  def for_user_id(user_id, provider) do
    Repo.get_by(ExternalAccount, user_id: user_id, provider: provider)
  end

  defp maybe_sync_calendars(ea) do
    # Don't sync calendars in test, essentially. Enabling this leads to flaky tests.
    if Application.get_env(:walt_ui, :calendar_sync_enabled, true) do
      Task.Supervisor.async_nolink(WaltUi.Calendars.TaskSupervisor, fn ->
        WaltUi.Calendars.initial_sync(ea)
      end)
    end
  end

  defp maybe_enqueue_historical_email_sync(ea) do
    if ea.provider == :google &&
         Application.get_env(:walt_ui, :historical_email_sync_enabled, true) do
      %{external_account_id: ea.id}
      |> HistoricalEmailSyncJob.new()
      |> Oban.insert()
    end
  end

  defp format_attrs(nil, _auth_payload), do: %{}

  defp format_attrs(user, auth_payload) do
    expires_at_usec = DateTime.from_unix!(auth_payload.credentials.expires_at, :second)

    %{
      user_id: user.id,
      email: Map.get(auth_payload.info, :email),
      provider: :google,
      provider_user_id: Map.get(auth_payload, :uid),
      access_token: auth_payload.credentials.token,
      refresh_token: auth_payload.credentials.refresh_token,
      expires_at: expires_at_usec
    }
  end
end
