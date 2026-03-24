defmodule CQRS.Meetings.Commands.Create do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :attendees, list(), default: []
    field :calendar_id, Ecto.UUID.t(), enforce: true
    field :end_time, NaiveDateTime.t()
    field :id, Ecto.UUID.t(), enforce: true
    field :kind, String.t()
    field :link, String.t()
    field :location, String.t()
    field :name, String.t(), enforce: true, default: "(No Title)"
    field :source_id, String.t(), enforce: true
    field :start_time, NaiveDateTime.t()
    field :status, String.t()
    field :user_id, Ecto.UUID.t(), enforce: true
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{
        attendees: {:array, :map},
        calendar_id: :binary_id,
        email: :string,
        end_time: :naive_datetime,
        id: :binary_id,
        kind: :string,
        link: :string,
        location: :string,
        name: :string,
        source_id: :string,
        start_time: :naive_datetime,
        status: :string,
        user_id: :binary_id
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :source_id, :calendar_id, :user_id])
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
