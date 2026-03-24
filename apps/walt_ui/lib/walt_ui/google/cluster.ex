defmodule WaltUi.Google.Cluster do
  @moduledoc false

  alias Cluster.Strategy.State
  alias WaltUi.Google.Cluster.Instances

  def get_nodes(%State{config: config}) do
    project = Keyword.get(config, :project, "heywalt")

    with {:ok, token} <- get_token() do
      nodes =
        project
        |> Instances.internal_dns(token)
        |> Enum.map(&:"walt_ui@#{&1}")
        |> Enum.reject(&(&1 == node()))

      {:ok, nodes}
    end
  end

  defp get_token do
    case Goth.fetch(WaltUi.Goth) do
      {:ok, token} -> {:ok, token.token}
      {:error, _} -> {:error, :google_not_authenticated}
    end
  end
end
