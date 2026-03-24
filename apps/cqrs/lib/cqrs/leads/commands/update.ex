defmodule CQRS.Leads.Commands.Update do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :attrs, map, enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
    field :user_id, Ecto.UUID.t(), enforce: true
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{id: :binary_id, attrs: :map, timestamp: :naive_datetime, user_id: :binary_id}

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :attrs, :timestamp, :user_id])
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
