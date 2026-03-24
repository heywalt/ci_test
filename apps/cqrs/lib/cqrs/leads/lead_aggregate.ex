defmodule CQRS.Leads.LeadAggregate do
  @moduledoc false

  use TypedStruct

  require Logger

  alias __MODULE__, as: Lead
  alias CQRS.Leads.Commands, as: Cmd
  alias CQRS.Leads.Events

  defmodule Lifespan do
    @moduledoc false

    @behaviour Commanded.Aggregates.AggregateLifespan

    @impl true
    def after_command(_cmd), do: :infinity

    @impl true
    def after_event(%CQRS.Leads.Events.LeadDeleted{}), do: :stop
    def after_event(_event), do: :infinity

    @impl true
    def after_error(error) do
      if is_exception(error) do
        {:stop, error}
      else
        :infinity
      end
    end
  end

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t()
    field :anniversary, Date.t()
    field :avatar, String.t()
    field :birthday, Date.t()
    field :city, String.t()
    field :correspondence_ids, list, default: []
    field :date_of_home_purchase, Date.t()
    field :email, String.t()
    field :emails, {:array, :map}, default: []
    field :enrichment_id, Ecto.UUID.t()
    field :enrichment_type, :best | :lesser | nil
    field :first_name, String.t()
    field :is_deleted, boolean, default: false
    field :is_favorite, boolean
    field :is_hidden, boolean, default: false
    field :jitter, integer, default: 0
    field :last_name, String.t()
    field :latitude, Decimal.t()
    field :longitude, Decimal.t()
    field :phone, String.t()
    field :phone_numbers, {:array, :map}, default: []
    field :ptt, integer
    field :remote_id, String.t()
    field :remote_source, String.t()
    field :state, String.t()
    field :street_1, String.t()
    field :street_2, String.t()
    field :unified_contact_id, Ecto.UUID.t()
    field :user_id, Ecto.UUID.t()
    field :zip, String.t()
  end

  # emit created event if aggregate is new
  def execute(%Lead{id: nil}, %Cmd.Create{} = cmd) do
    %Events.LeadCreated{
      id: cmd.id,
      anniversary: cmd.anniversary,
      avatar: cmd.avatar,
      birthday: cmd.birthday,
      city: cmd.city,
      date_of_home_purchase: cmd.date_of_home_purchase,
      email: cmd.email,
      emails: cmd.emails,
      first_name: cmd.first_name,
      is_favorite: cmd.is_favorite,
      last_name: cmd.last_name,
      phone: cmd.phone,
      phone_numbers: cmd.phone_numbers,
      ptt: cmd.ptt,
      remote_id: cmd.remote_id,
      remote_source: cmd.remote_source,
      state: cmd.state,
      street_1: cmd.street_1,
      street_2: cmd.street_2,
      timestamp: cmd.timestamp,
      unified_contact_id: cmd.unified_contact_id,
      user_id: cmd.user_id,
      zip: cmd.zip
    }
  end

  # emit created event if old aggregate had been deleted
  def execute(%Lead{id: id, is_deleted: true}, %Cmd.Create{id: id} = cmd) do
    %Events.LeadCreated{
      id: cmd.id,
      anniversary: cmd.anniversary,
      avatar: cmd.avatar,
      birthday: cmd.birthday,
      city: cmd.city,
      date_of_home_purchase: cmd.date_of_home_purchase,
      email: cmd.email,
      emails: cmd.emails,
      first_name: cmd.first_name,
      is_favorite: cmd.is_favorite,
      last_name: cmd.last_name,
      phone: cmd.phone,
      phone_numbers: cmd.phone_numbers,
      ptt: cmd.ptt,
      remote_id: cmd.remote_id,
      remote_source: cmd.remote_source,
      state: cmd.state,
      street_1: cmd.street_1,
      street_2: cmd.street_2,
      timestamp: cmd.timestamp,
      unified_contact_id: cmd.unified_contact_id,
      user_id: cmd.user_id,
      zip: cmd.zip
    }
  end

  # no-op when trying to create an existing, non-deleted aggregate
  def execute(%Lead{id: id}, %Cmd.Create{id: id}) do
    Logger.warning("Tried to create an existing aggregate", contact_id: id)
  end

  def execute(%Lead{id: id} = lead, %Cmd.Delete{id: id}) do
    %Events.LeadDeleted{
      id: id,
      timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      user_id: lead.user_id
    }
  end

  def execute(%Lead{} = lead, %Cmd.Update{} = cmd) do
    cmd.attrs
    |> CQRS.Utils.atom_map()
    |> Enum.reduce([], fn {key, val}, acc ->
      case {Map.get(lead, key), val} do
        {old_val, old_val} -> acc
        {old_val, new_val} -> [%{field: key, new: new_val, old: old_val} | acc]
      end
    end)
    |> case do
      [] ->
        []

      meta ->
        %Events.LeadUpdated{
          id: lead.id,
          attrs: cmd.attrs,
          metadata: meta,
          timestamp: cmd.timestamp,
          user_id: cmd.user_id
        }
    end
  end

  def execute(%Lead{}, %Cmd.Unify{} = cmd) do
    %Events.LeadUnified{
      id: cmd.id,
      city: cmd.city,
      enrichment_id: cmd.enrichment_id,
      enrichment_type: cmd.enrichment_type,
      ptt: cmd.ptt,
      state: cmd.state,
      street_1: cmd.street_1,
      street_2: cmd.street_2,
      timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
      zip: cmd.zip
    }
  end

  def execute(%Lead{id: id} = lead, %Cmd.JitterPtt{id: id} = cmd) do
    if cmd.score != lead.jitter do
      %Events.PttJittered{id: id, score: cmd.score, timestamp: cmd.timestamp}
    end
  end

  def execute(%Lead{}, %Cmd.InviteContact{} = cmd) do
    %Events.ContactInvited{
      calendar_id: cmd.calendar_id,
      end_time: cmd.end_time,
      id: cmd.id,
      kind: cmd.kind,
      link: cmd.link,
      location: cmd.location,
      meeting_id: cmd.meeting_id,
      name: cmd.name,
      source_id: cmd.source_id,
      start_time: cmd.start_time,
      status: cmd.status,
      user_id: cmd.user_id
    }
  end

  def execute(%Lead{} = lead, %Cmd.ResetPttHistory{} = cmd) do
    [
      %Events.LeadUpdated{
        id: cmd.id,
        attrs: %{ptt: 0},
        metadata: [%{field: :ptt, new: 0, old: lead.ptt}],
        timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second),
        user_id: lead.user_id
      },
      %Events.PttHistoryReset{id: cmd.id, reason: cmd.reason}
    ]
  end

  def execute(%Lead{} = lead, %Cmd.Correspond{} = cmd) do
    case already_corresponded?(lead, cmd) do
      true ->
        :ok

      false ->
        %Events.ContactCorresponded{
          direction: cmd.direction,
          from: cmd.from,
          id: cmd.id,
          meeting_time: cmd.meeting_time,
          message_link: cmd.message_link,
          source: cmd.source,
          source_id: cmd.source_id,
          source_thread_id: cmd.source_thread_id,
          subject: cmd.subject,
          to: cmd.to,
          user_id: cmd.user_id
        }
    end
  end

  def execute(_lead, %Cmd.SelectAddress{} = cmd) do
    %Events.AddressSelected{
      id: cmd.id,
      street_1: cmd.street_1,
      street_2: cmd.street_2,
      city: cmd.city,
      state: cmd.state,
      zip: cmd.zip
    }
  end

  def apply(%Lead{}, %Events.LeadCreated{} = event) do
    %Lead{
      id: event.id,
      anniversary: event.anniversary,
      avatar: event.avatar,
      birthday: event.birthday,
      city: event.city,
      date_of_home_purchase: event.date_of_home_purchase,
      email: event.email,
      first_name: event.first_name,
      is_deleted: false,
      is_favorite: event.is_favorite,
      last_name: event.last_name,
      phone: event.phone,
      ptt: event.ptt,
      remote_id: event.remote_id,
      remote_source: event.remote_source,
      state: event.state,
      street_1: event.street_1,
      street_2: event.street_2,
      unified_contact_id: event.unified_contact_id,
      user_id: event.user_id,
      zip: event.zip
    }
  end

  def apply(%Lead{} = lead, %Events.LeadDeleted{}) do
    %Lead{lead | is_deleted: true}
  end

  def apply(%Lead{} = lead, %Events.LeadUpdated{metadata: meta}) do
    Enum.reduce(meta, lead, fn %{field: key, new: val}, acc ->
      Map.put(acc, CQRS.Utils.string_to_atom(key), val)
    end)
  end

  def apply(%Lead{} = lead, %Events.LeadUnified{} = event) do
    %Lead{
      lead
      | enrichment_id: event.enrichment_id,
        enrichment_type: event.enrichment_type,
        ptt: event.ptt,
        street_1: event.street_1,
        street_2: event.street_2,
        city: event.city,
        state: event.state,
        zip: event.zip
    }
  end

  def apply(%Lead{} = lead, %Events.PttJittered{} = event) do
    %{lead | jitter: event.score}
  end

  def apply(%Lead{} = lead, %Events.ContactInvited{}), do: lead

  def apply(%Lead{} = lead, %Events.PttHistoryReset{}) do
    %{lead | jitter: 0, ptt: 0}
  end

  def apply(%Lead{} = lead, %Events.ContactCorresponded{} = event) do
    correspondence_ids = [event.source_id | lead.correspondence_ids]

    %{lead | correspondence_ids: correspondence_ids}
  end

  def apply(%Lead{} = lead, %Events.AddressSelected{} = event) do
    %{
      lead
      | street_1: event.street_1,
        street_2: event.street_2,
        city: event.city,
        state: event.state,
        zip: event.zip
    }
  end

  defp already_corresponded?(lead, %Cmd.Correspond{source_id: source_id}) do
    Enum.member?(lead.correspondence_ids, source_id)
  end
end
