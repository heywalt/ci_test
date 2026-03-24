defmodule WaltUiWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use WaltUiWeb, :controller

  alias WaltUi.Error

  def call(conn, {:error, params_changeset: _}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: WaltUiWeb.ErrorJSON)
    |> render(:"400")
  end

  # This clause handles errors returned by Ecto's insert/update/delete.
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: WaltUiWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # This clause is an example of how to handle resources that cannot be found.
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: WaltUiWeb.ErrorHTML, json: WaltUiWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(html: WaltUiWeb.ErrorHTML, json: WaltUiWeb.ErrorJSON)
    |> render(:"401")
  end

  def call(conn, {:error, %Error{reason_atom: :not_found}}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: WaltUiWeb.ErrorHTML, json: WaltUiWeb.ErrorJSON)
    |> render(:"404")
  end

  def call(conn, {:error, _error}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(html: WaltUiWeb.ErrorHTML, json: WaltUiWeb.ErrorJSON)
    |> render(:"422")
  end
end
