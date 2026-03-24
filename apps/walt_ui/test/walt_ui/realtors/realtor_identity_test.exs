defmodule WaltUi.Realtors.RealtorIdentityTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Realtors.RealtorIdentity

  describe "changeset/2" do
    test "valid with email" do
      attrs = %{email: "agent@example.com"}
      changeset = RealtorIdentity.changeset(%RealtorIdentity{}, attrs)

      assert changeset.valid?
    end

    test "invalid with missing email" do
      changeset = RealtorIdentity.changeset(%RealtorIdentity{}, %{})

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:email)
    end

    test "invalid with empty string email" do
      changeset = RealtorIdentity.changeset(%RealtorIdentity{}, %{email: ""})

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:email)
    end

    test "unique constraint on email (case-insensitive)" do
      insert(:realtor_identity, email: "agent@example.com")

      {:error, changeset} =
        %RealtorIdentity{}
        |> RealtorIdentity.changeset(%{email: "AGENT@example.com"})
        |> Repo.insert()

      assert errors_on(changeset) |> Map.has_key?(:email)
    end
  end
end
