defmodule WaltUiWeb.Api.Documents.DocumentView do
  use JSONAPI.View, type: "documents", paginator: WaltUiWeb.Paginator

  def fields do
    [
      :city,
      :contacts,
      :document_count,
      :envelope_count,
      :external_link,
      :mls_number,
      :name,
      :street_1,
      :street_2,
      :type,
      :zip
    ]
  end

  def city(data, _conn), do: Map.get(data, :city)

  def contacts(data, _conn) do
    data
    |> Map.get(:contacts, [])
    |> Enum.map(&Map.take(&1, [:avatar, :city, :first_name, :id, :last_name, :ptt, :state]))
  end

  def document_count(data, _conn), do: Map.get(data, :document_count, 0)

  def envelope_count(data, _conn), do: Map.get(data, :envelope_count, 0)

  def external_link(%{id: id}, _conn) do
    "https://forms.skyslope.com/file-details/#{id}/documents"
  end

  def mls_number(data, _conn), do: Map.get(data, :mls_number)

  def street_1(data, _conn), do: Map.get(data, :street_1)

  def street_2(data, _conn), do: Map.get(data, :street_2)

  def zip(data, _conn), do: Map.get(data, :zip)
end
