defmodule WaltUi.HumanLoop do
  @moduledoc """
  Behaviour for HumanLoop, defining the callbacks required to interact with the HumanLoop API.
  """

  @client Application.compile_env(
            :walt_ui,
            [WaltUi.HumanLoop, :client],
            WaltUi.HumanLoop.Client
          )

  @callback call_prompt(String.t(), String.t(), map()) :: {:ok, map} | {:error, String.t()}
  @callback list_prompts() :: {:ok, map} | {:error, String.t()}

  @spec call_prompt(String.t(), String.t(), map()) :: {:ok, map} | {:error, String.t()}
  def call_prompt(prompt_id, contact, user) do
    @client.call_prompt(prompt_id, contact, user)
  end

  @spec list_prompts() :: {:ok, map} | {:error, String.t()}
  def list_prompts do
    @client.list_prompts()
  end
end
