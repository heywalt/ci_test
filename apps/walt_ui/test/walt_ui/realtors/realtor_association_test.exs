defmodule WaltUi.Realtors.RealtorAssociationTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Realtors.RealtorAssociation

  describe "changeset/2" do
    test "valid with name" do
      attrs = %{name: "National Association of Realtors"}
      changeset = RealtorAssociation.changeset(%RealtorAssociation{}, attrs)

      assert changeset.valid?
    end

    test "invalid with missing name" do
      changeset = RealtorAssociation.changeset(%RealtorAssociation{}, %{})

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:name)
    end

    test "unique constraint on name (case-insensitive)" do
      insert(:realtor_association, name: "National Association of Realtors")

      {:error, changeset} =
        %RealtorAssociation{}
        |> RealtorAssociation.changeset(%{name: "national association of realtors"})
        |> Repo.insert()

      assert errors_on(changeset) |> Map.has_key?(:name)
    end
  end
end
