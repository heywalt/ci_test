defmodule MarketingWeb.WellKnownController do
  use MarketingWeb, :controller

  def aasa(conn, _params) do
    file_path = well_known_file_path("apple-app-site-association")

    well_known_file_response(conn, file_path)
  end

  def assetlinks(conn, _params) do
    file_path = well_known_file_path("assetlinks.json")

    well_known_file_response(conn, file_path)
  end

  defp well_known_file_path(file) do
    Path.join([:code.priv_dir(:marketing), "static", ".well-known", file])
  end

  defp well_known_file_response(conn, file_path) do
    case File.read(file_path) do
      {:ok, json} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, json)

      _ ->
        send_resp(conn, 404, "Not Found")
    end
  end
end
