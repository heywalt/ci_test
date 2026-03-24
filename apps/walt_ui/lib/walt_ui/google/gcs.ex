defmodule WaltUi.Google.Gcs do
  @moduledoc """
  Module for interacting with Google Cloud Storage.
  """

  alias WaltUi.Account.User

  @bucket "hey-walt-contacts"
  @root_domain "storage.googleapis.com"

  @spec file_delivery_url(String.t()) :: String.t() | nil
  def file_delivery_url(nil), do: nil
  def file_delivery_url(""), do: nil

  def file_delivery_url(path) do
    case String.contains?(path, "http") do
      # protocol detected, must be a full URL
      true ->
        path

      false ->
        "https://#{@root_domain}/#{@bucket}/#{path}"
    end
  end

  @spec gen_random_upload(User, String.t(), String.t()) ::
          {:error, String.t()} | {:ok, String.t()}
  def gen_random_upload(user, scope, extention) do
    sa_json = config()[:service_account_credentials_json] |> Jason.decode!()
    client = GcsSignedUrl.Client.load(sa_json)
    path = gen_file_path(user, scope, extention)

    GcsSignedUrl.generate_v4(client, @bucket, path, expires: 3600, verb: "PUT")
  end

  defp gen_file_path(user, scope, extention) do
    "#{user.id}/#{scope}/#{gen_random_file_name(extention)}"
  end

  defp gen_random_file_name(extention) do
    {:ok, hash} = Ecto.UUID.bingenerate() |> Ecto.UUID.load()
    "#{hash}.#{extention}"
  end

  defp config do
    Application.get_env(:walt_ui, :google)
  end
end
