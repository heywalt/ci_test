defmodule WaltUiWeb.Api.ImageJSON do
  @doc """
  Renders a signed url for image uploads.
  """
  def upload(%{url: url, filename: filename}) do
    %{url: url, filename: filename}
  end
end
