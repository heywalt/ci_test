defmodule WaltUiWeb.CowboyNoServerHeader do
  @moduledoc """
  Custom Cowboy stream handler to remove the Server header from responses.

  This is implemented as a stream handler for Cowboy 2.x, which is the
  recommended approach for modifying response headers at the HTTP adapter level.

  Stream handlers sit in the request/response pipeline and can intercept/modify
  responses before they're sent to the client.
  """

  @behaviour :cowboy_stream

  def init(streamid, req, opts) do
    {commands, next} = :cowboy_stream.init(streamid, req, opts)
    {commands, %{next: next}}
  end

  def data(streamid, is_fin, data, state) do
    %{next: next} = state
    {commands, next} = :cowboy_stream.data(streamid, is_fin, data, next)
    {commands, %{next: next}}
  end

  def info(streamid, {:response, status, headers, body}, state) do
    %{next: next} = state
    # Remove the server header before passing to the next handler
    headers = Map.delete(headers, "server")
    {commands, next} = :cowboy_stream.info(streamid, {:response, status, headers, body}, next)
    {commands, %{next: next}}
  end

  def info(streamid, info, state) do
    %{next: next} = state
    {commands, next} = :cowboy_stream.info(streamid, info, next)
    {commands, %{next: next}}
  end

  def terminate(streamid, reason, state) do
    %{next: next} = state
    :cowboy_stream.terminate(streamid, reason, next)
  end

  def early_error(streamid, reason, partial_req, resp, opts) do
    :cowboy_stream.early_error(streamid, reason, partial_req, resp, opts)
  end
end
