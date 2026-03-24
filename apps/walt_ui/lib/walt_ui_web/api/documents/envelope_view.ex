defmodule WaltUiWeb.Api.Documents.EnvelopeView do
  use JSONAPI.View, type: "envelopes", paginator: WaltUiWeb.Paginator

  def fields do
    [
      :document_count,
      :external_link,
      :file_id,
      :id,
      :name,
      :signer_count,
      :status
    ]
  end

  def external_link(%{file_id: file_id}, _conn) do
    "https://forms.skyslope.com/file-details/#{file_id}/envelopes"
  end
end
