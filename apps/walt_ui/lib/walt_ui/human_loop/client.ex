defmodule WaltUi.HumanLoop.Client do
  @moduledoc """
  Context for interacting with HumanLoop.
  """

  alias WaltUi.HumanLoop.Http

  def call_prompt(prompt_id, contact, user) do
    Http.call_prompt(prompt_id, contact, user)
  end

  def list_prompts do
    Http.list_prompts()
  end
end
