defmodule Marketing.Sitemap do
  @moduledoc """
  Generates a sitemap for the marketing site
  """

  use MarketingWeb, :verified_routes

  @doc """
  Generates the sitemap.xml file and returns the XML content as a string
  """
  def generate do
    urls = get_urls()
    url_elements = Enum.map(urls, &build_url_element/1)

    ~s"""
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{url_elements}
    </urlset>\
    """
  end

  @doc """
  Writes the sitemap to a file in the priv/static directory
  """
  def generate_file do
    file_path = Application.app_dir(:marketing, "priv/static/sitemap.xml")
    content = generate()

    File.write!(file_path, content)

    file_path
  end

  defp get_urls do
    [
      %{
        loc: url(~p"/"),
        lastmod: Date.utc_today() |> Date.to_iso8601()
      },
      %{
        loc: url(~p"/privacy"),
        lastmod: Date.utc_today() |> Date.to_iso8601()
      },
      %{
        loc: url(~p"/terms"),
        lastmod: Date.utc_today() |> Date.to_iso8601()
      }
    ]
  end

  defp build_url_element(%{loc: loc, lastmod: lastmod}) do
    ~s"""
      <url>
        <loc>#{escape_xml(loc)}</loc>
        <lastmod>#{lastmod}</lastmod>
      </url>\
    """
  end

  defp escape_xml(string) do
    string
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
