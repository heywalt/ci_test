defmodule WaltUi.Tags do
  @moduledoc """
  The Tags context.
  """
  import Ecto.Query

  alias WaltUi.Account.User
  alias WaltUi.Tags.Tag

  @spec create_tag(map(), User.t()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def create_tag(attrs, user) do
    attrs = Map.put(attrs, :user_id, user.id)

    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_tags(Ecto.UUID.t()) :: [Tag.t()]
  def list_tags(user_id) do
    Repo.all(from t in Tag, where: t.user_id == ^user_id)
  end

  @spec get_tag(Ecto.UUID.t()) :: {:ok, Tag.t()} | {:error, :not_found}
  def get_tag(id) do
    Tag
    |> Repo.get(id)
    |> case do
      nil ->
        {:error, :not_found}

      tag ->
        {:ok, tag}
    end
  end

  @spec update_tag(Tag.t(), map()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def update_tag(tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_tag(Tag.t()) :: {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def delete_tag(tag) do
    Repo.delete(tag)
  end

  @spec find_or_create_tag(Ecto.UUID.t(), String.t(), String.t()) ::
          {:ok, Tag.t()} | {:error, Ecto.Changeset.t()}
  def find_or_create_tag(user_id, name, color) do
    case Repo.get_by(Tag, user_id: user_id, name: name) do
      nil ->
        create_tag(%{name: name, color: color}, %User{id: user_id})

      existing_tag ->
        {:ok, existing_tag}
    end
  end
end
