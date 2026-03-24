defmodule CQRS.Middleware.CommandValidation do
  @moduledoc false

  @behaviour Commanded.Middleware

  alias Commanded.Middleware.Pipeline
  alias CQRS.Certifiable

  @impl true
  def before_dispatch(%Pipeline{command: cmd} = pipeline) do
    case Certifiable.certify(cmd) do
      :ok ->
        pipeline

      {:error, error} ->
        pipeline
        |> Pipeline.respond({:error, error})
        |> Pipeline.halt()
    end
  end

  @impl true
  def after_dispatch(pipeline), do: pipeline

  @impl true
  def after_failure(pipeline), do: pipeline
end
