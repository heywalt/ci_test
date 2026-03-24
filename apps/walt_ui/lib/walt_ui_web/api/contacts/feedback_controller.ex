defmodule WaltUiWeb.Api.Contacts.FeedbackController do
  use WaltUiWeb, :controller

  alias WaltUi.Contacts
  alias WaltUi.Feedbacks
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  def create(conn, %{"id" => contact_id, "comment" => comment}) do
    current_user = conn.assigns.current_user

    with {:ok, contact} <- Contacts.fetch_contact(contact_id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :create_feedback, contact),
         {:ok, _feedback} <-
           Feedbacks.create_feedback(%{comment: comment, contact_id: contact_id}) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(:no_content, "")
    end
  end
end
