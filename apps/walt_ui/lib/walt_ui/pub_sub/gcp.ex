defmodule WaltUi.PubSub.Gcp do
  @moduledoc false

  @behaviour WaltUi.PubSub

  require Logger

  alias GoogleApi.PubSub.V1.Api.Projects
  alias GoogleApi.PubSub.V1.Model.PublishRequest
  alias GoogleApi.PubSub.V1.Model.PubsubMessage

  defmodule Connection do
    @moduledoc false
    use GoogleApi.Gax.Connection,
      otp_app: :walt_ui,
      base_url: "https://www.googleapis.com"
  end

  @impl true
  def send_message(message, opts) do
    topic = Keyword.get(opts, :topic, "create-contacts")

    with {:ok, conn} <- conn(),
         {:ok, message} <- Jason.encode(message),
         request = %PublishRequest{messages: [%PubsubMessage{data: Base.encode64(message)}]},
         {:ok, _} <-
           Projects.pubsub_projects_topics_publish(conn, "heywalt", topic, body: request) do
      :ok
    end
  end

  defp conn do
    case Goth.fetch(WaltUi.Goth) do
      {:ok, token} -> {:ok, Connection.new(token.token)}
      {:error, _} -> {:error, :google_not_authenticated}
    end
  end
end
