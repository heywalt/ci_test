defmodule WaltUi.Calendars do
  @moduledoc """
  The Calendars context.
  """
  import Ecto.Query, warn: false

  alias WaltUi.Account.User
  alias WaltUi.Calendars.Calendar
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.Google.Calendars, as: Gcals
  alias WaltUi.Projections.Contact

  @spec initial_sync(ExternalAccount.t()) :: [{:ok, map} | {:error, term}]
  def initial_sync(%{provider: :google} = external_account) do
    Gcals.initial_sync(external_account)
  end

  # Fallthrough for sources that we aren't trying to sync calendars for.
  def initial_sync(_external_account), do: []

  def sync(%{provider: :google} = ea) do
    Gcals.sync_events_for_external_account(ea)
  end

  def sync(_ea), do: nil

  @spec get(Ecto.UUID.t()) :: {:ok, Calendar.t()} | {:error, nil}
  def get(id) do
    case Repo.get(Calendar, id) do
      nil -> {:error, nil}
      calendar -> {:ok, calendar}
    end
  end

  @spec get_todays_events(ExternalAccount.t(), String.t()) :: [map]
  def get_todays_events(ea, timezone) do
    Gcals.get_todays_events(ea, timezone)
  end

  @spec for_user_id_and_source(Ecto.UUID.t(), atom(), String.t()) :: Calendar.t() | nil
  def for_user_id_and_source(user_id, source, source_id) do
    Repo.get_by(Calendar, user_id: user_id, source: source, source_id: source_id)
  end

  @spec get_todays_events_with_contacts(User.t(), ExternalAccount.t(), String.t()) :: [map]
  def get_todays_events_with_contacts(current_user, ea, timezone) do
    events = get_todays_events(ea, timezone)

    walt_calendar = for_user_id_and_source(current_user.id, :google, ea.email)

    Enum.map(events, fn event ->
      attendees_emails =
        case Map.get(event, :attendees) do
          nil ->
            []

          attendees ->
            attendees
            |> Enum.map(& &1[:email])
            |> Enum.reject(&is_nil/1)
            |> Enum.uniq()
            |> List.delete(ea.email)
        end

      q =
        from c in Contact,
          where:
            c.user_id == ^current_user.id and
              (c.email in ^attendees_emails or
                 fragment(
                   "EXISTS (SELECT 1 FROM unnest(COALESCE(?, '{}'::jsonb[])) AS elem WHERE elem->>'email' = ANY(?))",
                   c.emails,
                   ^attendees_emails
                 )),
          select: %{id: c.id, remote_id: c.remote_id, avatar: c.avatar}

      attendee_contacts = Repo.all(q)

      event
      |> Map.put(:attendee_contacts, attendee_contacts)
      |> Map.put(:color, walt_calendar.color)
    end)
  end

  @spec create(map(), User.t(), atom) :: {:ok, Calendar.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs, %User{id: user_id}, source) do
    attrs = format_attrs(attrs, user_id, source)

    %Calendar{}
    |> Calendar.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:name, :color, :timezone, :updated_at]},
      conflict_target: [:user_id, :source_id]
    )
  end

  @spec create!(map(), User.t(), atom) :: Calendar.t()
  def create!(attrs, user_id, source) do
    attrs = format_attrs(attrs, user_id, source)

    %Calendar{}
    |> Calendar.changeset(attrs)
    |> Repo.insert!(
      on_conflict: {:replace, [:name, :color, :timezone, :updated_at]},
      conflict_target: [:user_id, :source_id]
    )
  end

  @spec list(Ecto.UUID.t()) :: list(Calendar.t())
  def list(user_id) do
    Repo.all(from c in Calendar, where: c.user_id == ^user_id)
  end

  @spec update(Calendar.t(), map) :: {:ok, Calendar.t()} | {:error, Ecto.Changeset.t()}
  def update(calendar, attrs) do
    calendar
    |> Calendar.changeset(attrs)
    |> Repo.update()
  end

  def update!(calendar, attrs) do
    attrs = format_attrs(attrs, calendar.user_id, calendar.source)

    calendar
    |> Calendar.changeset(attrs)
    |> Repo.update!()
  end

  @spec create_appointment(ExternalAccount.t(), Calendar.t(), map) :: {:ok, map} | {:error, map}
  def create_appointment(ea, calendar, %{provider: "google"} = params) do
    Gcals.create_appointment(ea, calendar, params)
  end

  @spec delete(Calendar.t()) :: {:ok, Calendar.t()}
  def delete(calendar) do
    Repo.delete(calendar)
  end

  defp format_attrs(%{id: source_id, summary: name} = attrs, user_id, source) do
    attrs
    |> Map.drop([:id])
    |> Map.merge(%{
      color: attrs.backgroundColor,
      source: source,
      source_id: source_id,
      name: name,
      user_id: user_id,
      timezone: attrs.timeZone
    })
  end
end
