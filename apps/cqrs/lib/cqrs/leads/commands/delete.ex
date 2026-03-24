defmodule CQRS.Leads.Commands.Delete do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
  end

  defimpl CQRS.Certifiable do
    # This command is validated by being properly dispatched
    # to an aggregate, since its only field is the root entity id.
    def certify(_cmd), do: :ok
  end
end
