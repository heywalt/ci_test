defmodule CQRS.Leads.Commands.ResetPttHistory do
  @moduledoc false

  use TypedStruct

  @derive Jason.Encoder
  typedstruct do
    field :id, Ecto.UUID.t(), enforce: true
    field :reason, String.t()
  end

  defimpl CQRS.Certifiable do
    def certify(_cmd), do: :ok
  end
end
