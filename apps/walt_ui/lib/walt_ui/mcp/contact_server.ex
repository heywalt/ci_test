defmodule WaltUi.MCP.ContactServer do
  @moduledoc """
  MCP Server that exposes Walt UI contact data as tools for AI models.
  Uses Anubis MCP to define tools that can be called by Vertex AI.
  """

  use Anubis.Server,
    name: "walt-contacts",
    version: "1.0.0",
    capabilities: [:tools]

  component(WaltUi.MCP.Tools.AnalyzeMoveScoreTrends)
  component(WaltUi.MCP.Tools.CreateNote)
  component(WaltUi.MCP.Tools.GetContactDetails)
  component(WaltUi.MCP.Tools.GetContactPttHistory)
  component(WaltUi.MCP.Tools.GetContactTimeline)
  component(WaltUi.MCP.Tools.SearchContacts)
  component(WaltUi.MCP.Tools.SearchEmails)
  component(WaltUi.MCP.Tools.SearchNotes)
end
