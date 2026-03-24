defmodule WaltUi.PubSub do
  @moduledoc false

  @callback send_message(map(), Keyword.t()) :: :ok | {:error, term()}

  @spec send_message(map) :: :ok | {:error, term()}
  def send_message(message, opts \\ []) do
    client().send_message(message, opts)
  end

  defp client do
    :walt_ui
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:client, WaltUi.PubSub.Gcp)
  end
end
