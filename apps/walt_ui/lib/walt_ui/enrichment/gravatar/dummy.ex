defmodule WaltUi.Enrichment.Gravatar.Dummy do
  @moduledoc """
  Dummy implementation of the Gravatar behaviour.
  """
  @behaviour WaltUi.Enrichment.Gravatar

  @impl true
  def get_avatar(_slug), do: {:error, %{status: 404}}
end
