defmodule WaltUiWeb.Api.DocumentsController do
  use WaltUiWeb, :controller

  import CozyParams

  alias WaltUi.ExternalAccounts
  alias WaltUi.Skyslope

  action_fallback WaltUiWeb.FallbackController

  defparams :page_opts do
    field :page, :integer, default: 1
    field :size, :integer, default: 10
  end

  def index(conn, params) do
    current_user = conn.assigns.current_user
    page_params = Map.get(params, "page", %{})

    with {:ok, ea} <-
           ExternalAccounts.find_by_provider(current_user.external_accounts, :skyslope),
         {:ok, page_opts} <- page_opts(page_params),
         sky_opts = %{page: page_opts.page, pageSize: page_opts.size},
         {:ok, {total_count, files}} <- Skyslope.get_files(ea, sky_opts) do
      conn
      |> put_view(WaltUiWeb.Api.Documents.DocumentView)
      |> render(:index, %{
        data: files,
        paginate: %{
          page_number: page_opts.page,
          page_size: page_opts.size,
          total_pages: ceil(total_count / page_opts.size)
        }
      })
    end
  end

  def show(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, ea} <-
           ExternalAccounts.find_by_provider(current_user.external_accounts, :skyslope),
         {:ok, file} <- Skyslope.get_file(ea, id, current_user.id) do
      conn
      |> put_view(WaltUiWeb.Api.Documents.DocumentView)
      |> render(:show, %{data: file})
    end
  end

  def envelopes(conn, %{"id" => id} = params) do
    current_user = conn.assigns.current_user
    page_params = Map.get(params, "page", %{})

    with {:ok, ea} <-
           ExternalAccounts.find_by_provider(current_user.external_accounts, :skyslope),
         {:ok, page_opts} <- page_opts(page_params),
         sky_opts = %{page: page_opts.page, pageSize: page_opts.size},
         {:ok, file} <- Skyslope.get_file(ea, id, current_user.id),
         {:ok, {total_count, envelopes}} <- Skyslope.get_envelopes(ea, id, sky_opts) do
      envelopes = Enum.map(envelopes, &envelope_name(&1, file.name))

      conn
      |> put_view(WaltUiWeb.Api.Documents.EnvelopeView)
      |> render(:index, %{
        data: envelopes,
        paginate: %{
          page_number: page_opts.page,
          page_size: page_opts.size,
          total_pages: ceil(total_count / page_opts.size)
        }
      })
    end
  end

  defp envelope_name(%{name: nil} = env, file_name), do: %{env | name: file_name}
  defp envelope_name(envelope, _file_name), do: envelope
end
