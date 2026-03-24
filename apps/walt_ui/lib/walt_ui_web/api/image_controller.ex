defmodule WaltUiWeb.Api.ImageController do
  use WaltUiWeb, :controller

  alias WaltUi.Google.Gcs

  action_fallback WaltUiWeb.FallbackController

  def upload(conn, %{"scope" => scope, "extention" => extention}) do
    current_user = conn.assigns.current_user
    signed_url = Gcs.gen_random_upload(current_user, scope, extention)

    filename =
      signed_url
      |> URI.parse()
      |> Map.get(:path, "")
      |> String.replace("/hey-walt-contacts/", "")

    conn
    |> put_status(:ok)
    |> render(%{url: signed_url, filename: filename})
  end
end
