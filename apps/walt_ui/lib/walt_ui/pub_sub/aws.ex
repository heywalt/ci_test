defmodule WaltUi.PubSub.Aws do
  @moduledoc """
  Module for interacting with SQS within AWS
  """
  @behaviour WaltUi.PubSub

  require Logger

  @impl true
  def send_message(contact, opts) do
    queue_url =
      case Keyword.get(opts, :topic, "create-contacts") do
        "create-contacts" -> config(:create_contacts_url)
        "upsert-contacts" -> config(:upsert_contacts_url)
      end

    with {:ok, encoded} <- Jason.encode(contact),
         {:ok, _} <- ExAws.SQS.send_message(queue_url, encoded) |> ExAws.request() do
      :ok
    else
      {:error, error} ->
        Logger.error("Error encountered in publishing message to AWS SQS",
          details: inspect(error)
        )
    end
  end

  defp config(key) do
    Application.get_env(:ex_aws, :sqs)[key]
  end
end
