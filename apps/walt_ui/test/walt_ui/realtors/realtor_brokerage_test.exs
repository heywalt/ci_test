defmodule WaltUi.Realtors.RealtorBrokerageTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Realtors.RealtorBrokerage

  describe "changeset/2" do
    test "valid with name" do
      attrs = %{name: "Keller Williams Realty"}
      changeset = RealtorBrokerage.changeset(%RealtorBrokerage{}, attrs)

      assert changeset.valid?
    end

    test "invalid with missing name" do
      changeset = RealtorBrokerage.changeset(%RealtorBrokerage{}, %{})

      refute changeset.valid?
      assert errors_on(changeset) |> Map.has_key?(:name)
    end

    test "unique constraint on name (case-insensitive)" do
      insert(:realtor_brokerage, name: "Keller Williams Realty")

      {:error, changeset} =
        %RealtorBrokerage{}
        |> RealtorBrokerage.changeset(%{name: "keller williams realty"})
        |> Repo.insert()

      assert errors_on(changeset) |> Map.has_key?(:name)
    end
  end
end
