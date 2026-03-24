defmodule CQRS.Leads.Commands.JitterPtt do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :score, :integer, enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{id: :binary_id, score: :integer, timestamp: :naive_datetime}
      keys = Map.keys(types)

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), keys)
      |> validate_required(keys)
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
