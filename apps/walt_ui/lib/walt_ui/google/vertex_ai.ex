defmodule WaltUi.Google.VertexAI do
  @moduledoc """
  High-level API for Google Vertex AI queries with contact context.
  """

  alias WaltUi.Google.VertexAI.Client

  @doc """
  Query the AI with contact context available.
  """
  def query(prompt, user_id, opts \\ []) do
    Client.query(prompt, user_id, opts)
  end
end
