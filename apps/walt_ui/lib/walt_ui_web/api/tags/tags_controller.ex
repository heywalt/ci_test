defmodule WaltUiWeb.Api.TagsController do
  use WaltUiWeb, :controller

  import CozyParams

  alias WaltUi.Tags
  alias WaltUiWeb.Authorization

  action_fallback WaltUiWeb.FallbackController

  defparams :create_tag_params do
    field :name, :string, required: true
    field :color, :string, required: true
  end

  def create(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- create_tag_params(params),
         {:ok, tag} <- Tags.create_tag(params, current_user) do
      conn
      |> put_status(:created)
      |> json(%{data: tag})
    end
  end

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    tags = Tags.list_tags(current_user.id)

    conn
    |> put_status(:ok)
    |> json(%{data: tags})
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, tag} <- Tags.get_tag(id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :view, tag) do
      conn
      |> put_status(:ok)
      |> json(%{data: tag})
    end
  end

  defparams :update_tag_params do
    field :name, :string
    field :color, :string
  end

  def update(conn, %{"id" => id, "tag" => tag_params}) do
    current_user = conn.assigns.current_user

    with {:ok, tag} <- Tags.get_tag(id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :update, tag),
         {:ok, params} <- update_tag_params(tag_params),
         {:ok, tag} <- Tags.update_tag(tag, params) do
      conn
      |> put_status(:ok)
      |> json(%{data: tag})
    end
  end

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, tag} <- Tags.get_tag(id),
         {:ok, :authorized} <- Authorization.authorize(current_user, :delete, tag),
         {:ok, _} <- Tags.delete_tag(tag) do
      conn
      |> put_status(:no_content)
      |> send_resp(:no_content, "")
    end
  end
end
