defmodule CQRS.Leads.Commands.Correspond do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :direction, String.t()
    field :from, String.t()
    field :id, Ecto.UUID.t(), enforce: true
    field :meeting_time, NaiveDateTime.t()
    field :message_link, String.t()
    field :source, String.t()
    field :source_id, String.t()
    field :source_thread_id, String.t()
    field :subject, String.t()
    field :to, String.t()
    field :user_id, Ecto.UUID.t(), enforce: true
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset

    def certify(cmd) do
      types = %{
        direction: :string,
        from: :string,
        id: :binary_id,
        meeting_time: :naive_datetime,
        message_link: :string,
        source: :string,
        source_id: :string,
        source_thread_id: :string,
        subject: :string,
        to: :string,
        user_id: :binary_id
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :source, :source_id, :user_id])
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
