defmodule WaltUi.TagsTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Tags
  alias WaltUi.Tags.Tag

  describe "create_tag/2" do
    test "creates a tag" do
      user = insert(:user, email: "test@example.com")
      attrs = %{name: "Test Tag", color: "#000000"}

      assert {:ok, %Tag{name: "Test Tag", color: "#000000"}} = Tags.create_tag(attrs, user)
    end

    test "returns error if tag already exists" do
      user = insert(:user, email: "test@example.com")
      attrs = %{name: "Test Tag", color: "#000000"}

      assert {:ok, %Tag{}} = Tags.create_tag(attrs, user)
      assert {:error, %Ecto.Changeset{}} = Tags.create_tag(attrs, user)
    end

    test "returns error if tag name is empty" do
      user = insert(:user, email: "test@example.com")
      attrs = %{name: "", color: "#000000"}

      assert {:error, %Ecto.Changeset{}} = Tags.create_tag(attrs, user)
    end

    test "returns error if tag color is empty" do
      user = insert(:user, email: "test@example.com")
      attrs = %{name: "Test Tag", color: ""}

      assert {:error, %Ecto.Changeset{}} = Tags.create_tag(attrs, user)
    end
  end

  describe "list_tags/1" do
    test "returns all tags for a user" do
      user = insert(:user, email: "test@example.com")
      _tag = insert(:tag, user: user)

      assert [%Tag{}] = Tags.list_tags(user.id)
    end
  end

  describe "get_tag/1" do
    test "returns a tag" do
      user = insert(:user, email: "test@example.com")
      tag = insert(:tag, name: "Test Tag Number 2", color: "#000000", user: user)

      assert {:ok, %Tag{name: "Test Tag Number 2", color: "#000000"}} = Tags.get_tag(tag.id)
    end
  end

  describe "update_tag/2" do
    test "updates a tag" do
      user = insert(:user, email: "test@example.com")
      tag = insert(:tag, name: "Test Tag Number 3", color: "#000000", user: user)

      assert {:ok, %{name: "Updated Tag"}} = Tags.update_tag(tag, %{name: "Updated Tag"})
    end
  end

  describe "delete_tag/1" do
    test "deletes a tag" do
      user = insert(:user, email: "test@example.com")
      tag = insert(:tag, user: user)

      assert {:ok, %Tag{}} = Tags.delete_tag(tag)
    end
  end

  describe "find_or_create_tag/3" do
    test "creates a new tag when it doesn't exist" do
      user = insert(:user)

      assert {:ok, %Tag{name: "VIP", color: "grey"}} =
               Tags.find_or_create_tag(user.id, "VIP", "grey")
    end

    test "returns existing tag when it already exists" do
      user = insert(:user)
      existing_tag = insert(:tag, user: user, name: "Important", color: "red")

      assert {:ok, returned_tag} =
               Tags.find_or_create_tag(user.id, "Important", "blue")

      # Should return the existing tag, not create a new one
      assert returned_tag.id == existing_tag.id
      # Original color, not the new one
      assert returned_tag.color == "red"
    end

    test "creates different tags for different users with same name" do
      user1 = insert(:user)
      user2 = insert(:user)

      assert {:ok, tag1} = Tags.find_or_create_tag(user1.id, "VIP", "grey")
      assert {:ok, tag2} = Tags.find_or_create_tag(user2.id, "VIP", "grey")

      assert tag1.id != tag2.id
      assert tag1.user_id == user1.id
      assert tag2.user_id == user2.id
    end

    test "returns error when tag creation fails" do
      user = insert(:user)

      # Try to create a tag with invalid attributes (empty name)
      assert {:error, %Ecto.Changeset{}} =
               Tags.find_or_create_tag(user.id, "", "grey")
    end
  end
end
