defmodule WaltUiWeb.Api.ContactTagsController do
  use WaltUiWeb, :controller

  import CozyParams

  alias WaltUi.ContactTags
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  defparams :create_contact_tag_params do
    field :contact_id, :string, required: true
    field :tag_id, :string, required: true
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- create_contact_tag_params(params),
         {:ok, contact_tag} <- ContactTags.create(params, current_user) do
      conn
      |> put_status(:created)
      |> json(%{data: contact_tag})
    end
  end

  defparams :index_params do
    field :contact_id, :string, required: true
  end

  def delete(conn, %{"contact_id" => contact_id, "tag_id" => tag_id}) do
    current_user = conn.assigns.current_user

    with {:ok, contact_tag} <-
           ContactTags.get_by_contact_id_and_tag_id(contact_id, tag_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :delete, contact_tag),
         {:ok, _} <- ContactTags.delete(contact_tag) do
      conn
      |> put_status(:no_content)
      |> send_resp(:no_content, "")
    end
  end
end
