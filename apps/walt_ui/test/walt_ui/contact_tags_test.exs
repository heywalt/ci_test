defmodule WaltUi.ContactTagsTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.ContactTags
  alias WaltUi.ContactTags.ContactTag

  describe "create_contact_tag/2" do
    test "creates a contact tag" do
      user = insert(:user, email: "test@example.com")
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)
      attrs = %{contact_id: contact.id, tag_id: tag.id}

      assert {:ok, %ContactTag{}} = ContactTags.create(attrs, user)
    end

    test "returns error if contact tag already exists" do
      user = insert(:user, email: "test@example.com")
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)
      attrs = %{contact_id: contact.id, tag_id: tag.id}

      assert {:ok, %ContactTag{}} = ContactTags.create(attrs, user)
      assert {:error, %Ecto.Changeset{}} = ContactTags.create(attrs, user)
    end

    test "returns error if contact_id is missing" do
      user = insert(:user, email: "test@example.com")
      tag = insert(:tag, user: user)
      attrs = %{tag_id: tag.id}

      assert {:error, %Ecto.Changeset{}} = ContactTags.create(attrs, user)
    end

    test "returns error if tag_id is missing" do
      user = insert(:user, email: "test@example.com")
      contact = insert(:contact, user_id: user.id)
      attrs = %{contact_id: contact.id}

      assert {:error, %Ecto.Changeset{}} = ContactTags.create(attrs, user)
    end
  end

  describe "get_contact_tag/1" do
    test "returns a contact tag" do
      user = insert(:user, email: "test@example.com")
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)
      contact_tag = insert(:contact_tag, user: user, contact_id: contact.id, tag: tag)

      assert {:ok, %ContactTag{}} = ContactTags.get(contact_tag.id)
    end
  end

  describe "delete_contact_tag/1" do
    test "deletes a contact tag" do
      user = insert(:user, email: "test@example.com")
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)
      contact_tag = insert(:contact_tag, user: user, contact_id: contact.id, tag: tag)

      assert {:ok, %ContactTag{}} = ContactTags.delete(contact_tag)
    end
  end

  describe "contact_tags_for_contact_id/1" do
    test "returns all tags as strings for a contact" do
      user = insert(:user, email: "test@example.com")
      contact = insert(:contact, user_id: user.id)
      tag1 = insert(:tag, name: "tag_1", user: user)
      tag2 = insert(:tag, name: "tag_2", user: user)

      insert(:contact_tag, user: user, contact_id: contact.id, tag: tag1)
      insert(:contact_tag, user: user, contact_id: contact.id, tag: tag2)

      assert tags = ContactTags.contact_tags_for_contact_id(contact.id)
      assert length(tags) == 2
      assert Enum.member?(tags, "tag_1")
      assert Enum.member?(tags, "tag_2")
    end

    test "returns an empty list if the contact has no tags" do
      user = insert(:user, email: "test@example.com")
      contact = insert(:contact, user_id: user.id)

      assert [] = ContactTags.contact_tags_for_contact_id(contact.id)
    end
  end

  describe "find_or_create/3" do
    test "creates a new contact tag when it doesn't exist" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)

      assert {:ok, %ContactTag{contact_id: contact_id, tag_id: tag_id}} =
               ContactTags.find_or_create(user.id, contact.id, tag.id)

      assert contact_id == contact.id
      assert tag_id == tag.id
    end

    test "returns existing contact tag when it already exists" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)
      tag = insert(:tag, user: user)
      existing_contact_tag = insert(:contact_tag, user: user, contact_id: contact.id, tag: tag)

      assert {:ok, returned_contact_tag} =
               ContactTags.find_or_create(user.id, contact.id, tag.id)

      # Should return the existing contact tag, not create a new one
      assert returned_contact_tag.id == existing_contact_tag.id
      assert returned_contact_tag.contact_id == contact.id
      assert returned_contact_tag.tag_id == tag.id
    end

    test "returns error when contact tag creation fails" do
      user = insert(:user)
      contact = insert(:contact, user_id: user.id)

      # Try to create a contact tag with invalid tag_id (non-existent)
      assert {:error, %Ecto.Changeset{}} =
               ContactTags.find_or_create(user.id, contact.id, Ecto.UUID.generate())
    end
  end
end
