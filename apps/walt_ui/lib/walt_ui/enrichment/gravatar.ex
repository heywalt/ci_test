defmodule WaltUi.Enrichment.Gravatar do
  @moduledoc """
  Behaviour for Gravatar HTTP implementations and context functions.
  """
  @callback get_avatar(String.t()) :: {:ok, Tesla.Env.t()} | {:error, term}

  @spec get_url(email :: String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_url(email) do
    slug = slug(email)

    case client().get_avatar(slug) do
      {:ok, %{status: code, url: url}} when code in 200..299 ->
        {:ok, url}

      _else ->
        {:error, :not_found}
    end
  end

  @spec slug(email :: String.t()) :: String.t()
  def slug(email) do
    email
    |> String.trim()
    |> String.downcase()
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode16(case: :lower)
  end

  defp client do
    :walt_ui
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:client, WaltUi.Enrichment.Gravatar.Http)
  end
end
