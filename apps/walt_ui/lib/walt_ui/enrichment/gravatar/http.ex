defmodule WaltUi.Enrichment.Gravatar.Http do
  @moduledoc """
  HTTP Client for interacting with Gravatar.
  """
  @behaviour WaltUi.Enrichment.Gravatar

  @impl true
  def get_avatar(slug) do
    Tesla.get(client(), "/#{slug}?d=404")
  end

  defp client do
    Tesla.client(
      [{Tesla.Middleware.BaseUrl, "https://gravatar.com/avatar"}],
      Tesla.Adapter.Hackney
    )
  end
end
