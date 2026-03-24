defmodule CQRS.Enrichments.Commands.RequestEnrichment do
  @moduledoc false

  use TypedStruct

  alias Repo.Types.TenDigitPhone

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :email, String.t()
    field :first_name, String.t()
    field :last_name, String.t()
    field :phone, TenDigitPhone.t(), enforce: true
    field :user_id, Ecto.UUID.t(), enforce: true
    field :timestamp, NaiveDateTime.t(), enforce: true
  end

  @spec new(map) :: t
  def new(attrs) do
    {ts, attrs} =
      Map.pop_lazy(attrs, :timestamp, fn ->
        NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      end)

    %__MODULE__{
      id: UUID.uuid5(:oid, attrs.phone),
      email: attrs.email,
      first_name: attrs.first_name,
      last_name: attrs.last_name,
      phone: attrs.phone,
      user_id: attrs.user_id,
      timestamp: ts
    }
  end

  defimpl CQRS.Certifiable do
    import Ecto.Changeset
    alias CQRS.Middleware.CommandValidation.ValidatePhone

    def certify(cmd) do
      types = %{
        id: :binary_id,
        email: :string,
        first_name: :string,
        last_name: :string,
        phone: :string,
        user_id: :binary_id,
        timestamp: :naive_datetime
      }

      {struct(cmd.__struct__), types}
      |> cast(Map.from_struct(cmd), Map.keys(types))
      |> validate_required([:id, :phone, :timestamp, :user_id])
      |> ValidatePhone.run()
      |> case do
        %{valid?: true} -> :ok
        changeset -> {:error, changeset.errors}
      end
    end
  end
end
