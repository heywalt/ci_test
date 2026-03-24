defmodule WaltUi.Providers do
  @moduledoc """
  Context functions for data providers.
  """

  alias WaltUi.Providers.Endato
  alias WaltUi.Providers.Faraday
  alias WaltUi.Providers.Gravatar

  @spec create_or_update_endato(Endato.t(), map | Keyword.t()) ::
          {:ok, Endato.t()} | {:error, Ecto.Changeset.t()}
  def create_or_update_endato(endato \\ %Endato{}, attrs) do
    attrs = Map.new(attrs)

    endato
    |> Endato.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @spec create_or_update_faraday_from_http(Faraday.t(), map, Ecto.UUID.t()) ::
          {:ok, Faraday.t()} | {:error, Ecto.Changeset.t()}
  def create_or_update_faraday_from_http(faraday \\ %Faraday{}, http_attrs, unified_contact_id) do
    faraday
    |> Faraday.http_changeset(http_attrs, %{unified_contact_id: unified_contact_id})
    |> Repo.insert_or_update()
  end

  @spec create_or_update_gravatar(Gravatar.t(), map) ::
          {:ok, Gravatar.t()} | {:error, Ecto.Changeset.t()}
  def create_or_update_gravatar(gravatar \\ %Gravatar{}, attrs) do
    gravatar
    |> Gravatar.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @spec get_endato(unified_contact_id :: Ecto.UUID.t()) :: Endato.t() | nil
  def get_endato(unified_contact_id) do
    Repo.get_by(Endato, unified_contact_id: unified_contact_id)
  end

  @spec get_faraday(unified_contact_id :: Ecto.UUID.t()) :: Faraday.t() | nil
  def get_faraday(unified_contact_id) do
    Repo.get_by(Faraday, unified_contact_id: unified_contact_id)
  end

  @spec get_gravatar(unified_contact_id :: Ecto.UUID.t()) :: Gravatar.t() | nil
  def get_gravatar(unified_contact_id) do
    Repo.get_by(Gravatar, unified_contact_id: unified_contact_id)
  end
end
