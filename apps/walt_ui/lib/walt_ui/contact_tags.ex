defmodule WaltUi.ContactTags do
  @moduledoc """
  The ContactTags context.
  """
  import Ecto.Query

  alias WaltUi.Account.User
  alias WaltUi.ContactTags.ContactTag
  alias WaltUi.Tags.Tag

  @spec create(map(), User.t()) ::
          {:ok, ContactTag.t()} | {:error, Ecto.Changeset.t()}
  def create(attrs, user) do
    attrs = Map.put(attrs, :user_id, user.id)

    %ContactTag{}
    |> ContactTag.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, contact_tag} ->
        update_tags_in_typesense(contact_tag.contact_id)

        {:ok, contact_tag}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @spec get(Ecto.UUID.t()) :: {:ok, ContactTag.t()} | {:error, :not_found}
  def get(id) do
    ContactTag
    |> Repo.get(id)
    |> case do
      nil ->
        {:error, :not_found}

      contact_tag ->
        {:ok, contact_tag}
    end
  end

  @spec get_by_contact_id_and_tag_id(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ContactTag.t()} | {:error, :not_found}
  def get_by_contact_id_and_tag_id(contact_id, tag_id) do
    ContactTag
    |> Repo.get_by(contact_id: contact_id, tag_id: tag_id)
    |> case do
      nil ->
        {:error, :not_found}

      contact_tag ->
        {:ok, contact_tag}
    end
  end

  @spec delete(ContactTag.t()) :: {:ok, ContactTag.t()} | {:error, Ecto.Changeset.t()}
  def delete(contact_tag) do
    case Repo.delete(contact_tag) do
      {:ok, contact_tag} ->
        update_tags_in_typesense(contact_tag.contact_id)

        {:ok, contact_tag}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @spec list_tags_for_contact(Ecto.UUID.t()) :: [Tag.t()]
  def list_tags_for_contact(contact_id) do
    Repo.all(
      from t in Tag,
        join: ct in ContactTag,
        on: ct.tag_id == t.id,
        where: ct.contact_id == ^contact_id
    )
  end

  def update_tags_in_typesense(contact_id) do
    Task.Supervisor.async_nolink(WaltUi.TaskSupervisor, fn ->
      contact_id
      |> contact_tags_for_contact_id()
      |> then(fn tags ->
        ExTypesense.update_document(%{
          id: contact_id,
          collection_name: "contacts",
          tags: tags
        })
      end)
    end)
  end

  @spec contact_tags_for_contact_id(Ecto.UUID.t()) :: [String.t()]
  def contact_tags_for_contact_id(contact_id) do
    Repo.all(
      from ct in ContactTag,
        where: ct.contact_id == ^contact_id,
        join: t in Tag,
        on: ct.tag_id == t.id,
        select: t.name
    )
  end

  @spec find_or_create(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ContactTag.t()} | {:error, Ecto.Changeset.t()}
  def find_or_create(user_id, contact_id, tag_id) do
    case Repo.get_by(ContactTag, contact_id: contact_id, tag_id: tag_id) do
      nil ->
        create(%{contact_id: contact_id, tag_id: tag_id}, %User{id: user_id})

      existing_contact_tag ->
        {:ok, existing_contact_tag}
    end
  end
end
