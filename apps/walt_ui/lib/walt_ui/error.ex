defmodule WaltUi.Error do
  @moduledoc """
  Error standardization.
  """
  @type t ::
          {:error,
           %__MODULE__{
             message: String.Chars.t(),
             reason_atom: atom() | nil,
             details: term() | nil
           }}

  @derive Jason.Encoder
  defexception [:message, :reason_atom, :details]

  @spec new(String.t(), Keyword.t()) :: t()
  def new(message, attrs \\ []) do
    {:error, struct(__MODULE__, attrs ++ [message: message])}
  end
end
