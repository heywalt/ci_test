defmodule CQRS.Leads.Commands.InviteContact do
  @moduledoc false

  use TypedStruct

  alias __MODULE__

  @derive Jason.Encoder
  typedstruct do
    field :calendar_id, Ecto.UUID.t(), enforce: true
    field :end_time, NaiveDateTime.t()
    field :id, Ecto.UUID.t(), enforce: true
    field :kind, String.t()
    field :link, String.t()
    field :location, String.t()
    field :meeting_id, Ecto.UUID.t(), enforce: true
    field :name, String.t(), enforce: true
    field :source_id, String.t(), enforce: true
    field :start_time, NaiveDateTime.t()
    field :status, String.t()
    field :user_id, Ecto.UUID.t(), enforce: true
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{
        calendar_id: :binary_id,
        end_time: :naive_datetime,
        id: :binary_id,
        kind: :string,
        link: :string,
        location: :string,
        meeting_id: :binary_id,
        name: :string,
        source_id: :string,
        start_time: :naive_datetime,
        status: :string,
        user_id: :binary_id
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:calendar_id, :id, :meeting_id, :name, :source_id, :user_id])
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end

  def new(map) do
    %InviteContact{
      calendar_id: map.calendar_id,
      end_time: map.end_time,
      id: map.id,
      kind: map.kind,
      link: map.link,
      location: map.location,
      name: map.name,
      meeting_id: map.meeting_id,
      source_id: map.source_id,
      start_time: map.start_time,
      status: map.status,
      user_id: map.user_id
    }
  end
end
