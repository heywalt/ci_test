defmodule WaltUiWeb.Api.EmailController do
  use WaltUiWeb, :controller

  import CozyParams

  require Logger

  alias WaltUi.Email
  alias WaltUi.ExternalAccounts

  action_fallback WaltUiWeb.FallbackController

  defparams :send_email_params do
    field :to, :string, required: true
    field :subject, :string, required: true
    field :body, :string, required: true
    field :provider, :string, required: true
  end

  def send_email(conn, params) do
    current_user = conn.assigns.current_user

    with {:ok, params} <- send_email_params(params),
         {:ok, ea} <-
           ExternalAccounts.find_by_provider(
             current_user.external_accounts,
             String.to_atom(params.provider)
           ),
         params = Map.put(params, :from, current_user.email),
         {:ok, _} <- Email.send_email(ea, params) do
      conn
      |> put_status(:no_content)
      |> send_resp(:no_content, "")
    end
  end
end
