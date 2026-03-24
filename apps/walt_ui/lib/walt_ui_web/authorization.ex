defmodule WaltUiWeb.Authorization do
  @moduledoc """
  Authorization logic.
  """

  alias WaltUi.Account.User
  alias WaltUi.Contacts
  alias WaltUi.ContactTags.ContactTag
  alias WaltUi.Directory.Note
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.Projections.Contact
  alias WaltUi.Tags.Tag
  alias WaltUi.Tasks.Task

  def authorize(%User{} = user, _action, %Contact{} = contact) do
    if contact.user_id == user.id do
      {:ok, :authorized}
    else
      {:error, :unauthorized}
    end
  end

  def authorize(%User{} = user, _action, %Task{} = task) do
    if task.user_id == user.id do
      {:ok, :authorized}
    else
      {:error, :unauthorized}
    end
  end

  def authorize(%User{} = _user, _action, :notes) do
    {:ok, :authorized}
  end

  def authorize(%User{} = user, _action, %Note{} = note) do
    case Contacts.fetch_contact(note.contact_id) do
      {:ok, contact} ->
        if contact.user_id == user.id do
          {:ok, :authorized}
        else
          {:error, :unauthorized}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def authorize(%User{} = user, _action, %ExternalAccount{} = external_account) do
    if external_account.user_id == user.id do
      {:ok, :authorized}
    else
      {:error, :unauthorized}
    end
  end

  def authorize(%User{} = user, _action, %Tag{} = tag) do
    if tag.user_id == user.id do
      {:ok, :authorized}
    else
      {:error, :unauthorized}
    end
  end

  def authorize(%User{} = user, _action, %ContactTag{} = contact_tag) do
    if contact_tag.user_id == user.id do
      {:ok, :authorized}
    else
      {:error, :unauthorized}
    end
  end

  def authorize(_subject, _action, _object) do
    {:error, :unauthorized}
  end
end
