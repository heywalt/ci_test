defmodule WaltUi.Skyslope do
  @moduledoc """
  Context for interacting with Skyslope.
  """
  require Logger

  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.ExternalAccountsAuthHelper, as: Auth
  alias WaltUi.Skyslope.Envelope
  alias WaltUi.Skyslope.File
  alias WaltUi.Skyslope.FileIndex

  @spec get_file(ExternalAccount.t(), integer, Ecto.UUID.t()) :: {:ok, File.t()} | {:error, term}
  def get_file(ext_acct, file_id, user_id) do
    with {:ok, token} <- Auth.get_latest_token(ext_acct) do
      token
      |> client()
      |> Tesla.get("/files/#{file_id}")
      |> handle_response(fn body -> File.from_http(body, user_id) end)
    end
  end

  @spec get_files(ExternalAccount.t(), Keyword.t()) ::
          {:ok, {non_neg_integer, [FileIndex.t()]}} | {:error, term}
  def get_files(external_account, query \\ []) do
    with {:ok, token} <- Auth.get_latest_token(external_account) do
      token
      |> client()
      |> Tesla.get("/files", query: query)
      |> handle_response(fn body ->
        files =
          body
          |> Map.get("files", [])
          |> Enum.map(&FileIndex.from_http/1)
          |> Enum.reject(&is_nil/1)

        total = get_integer(body, "totalRecords")

        Logger.info("Retrieved #{length(files)} of #{total} files from Skyslope",
          details: Map.get(body, "totalRecords"),
          user_id: external_account.user_id
        )

        {total, files}
      end)
    end
  end

  @spec get_envelopes(ExternalAccount.t(), pos_integer, Keyword.t()) ::
          {:ok, map} | {:error, term}
  def get_envelopes(ext_acct, file_id, query \\ []) do
    with {:ok, token} <- Auth.get_latest_token(ext_acct) do
      token
      |> client()
      |> Tesla.get("/files/#{file_id}/envelopes", query: query)
      |> handle_response(fn body ->
        envelopes =
          body
          |> Map.get("envelopes", [])
          |> Enum.map(&Envelope.from_http/1)
          |> Enum.reject(&is_nil/1)

        total = get_integer(body, "totalRecords")

        Logger.info("Retrieved #{length(envelopes)} of #{total} envelopes from Skyslope",
          details: Map.get(body, "totalRecords"),
          file_id: file_id,
          user_id: ext_acct.user_id
        )

        {total, envelopes}
      end)
    end
  end

  defp config do
    Application.get_env(:walt_ui, __MODULE__)
  end

  defp client(access_token) do
    Tesla.client(
      [
        {Tesla.Middleware.BaseUrl, config()[:base_url]},
        Tesla.Middleware.JSON,
        {Tesla.Middleware.BearerAuth, token: access_token}
      ],
      Tesla.Adapter.Hackney
    )
  end

  defp get_integer(map, key, default \\ 0) do
    map
    |> Map.get(key, default)
    |> then(fn
      val when is_integer(val) -> val
      val when is_binary(val) -> String.to_integer(val)
      val when is_float(val) -> ceil(val)
      _else -> default
    end)
  end

  defp handle_response({:ok, %{status: code} = resp}, callback) when code in 200..299 do
    {:ok, callback.(resp.body)}
  rescue
    e ->
      Logger.warning("Exception raised in response callback",
        details: inspect(e),
        module: __MODULE__,
        reason: Exception.message(e)
      )

      {:error, Exception.message(e)}
  end

  defp handle_response(response, _callback), do: handle_response(response)

  defp handle_response({:ok, %{status: 404}}) do
    Logger.warning("Files not found in Skyslope.")
    {:error, :not_found}
  end

  defp handle_response({:ok, %{status: 401}}) do
    Logger.warning("Unauthorized request to Skyslope.")
    {:error, :unauthorized}
  end

  defp handle_response({:error, response}) do
    Logger.warning("Unexpected Error Response from Skyslope", details: inspect(response))
    {:error, :unexpected_error}
  end
end
