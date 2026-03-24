defmodule CQRS.Enrichments.ValidationsTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset
  alias CQRS.Enrichments.Validations

  describe "validate_provider_type/1" do
    test "accepts valid provider types" do
      changeset =
        cast({%{}, %{provider_type: :any}}, %{provider_type: "faraday"}, [:provider_type])

      result = Validations.validate_provider_type(changeset)
      assert result.valid?
    end

    test "rejects invalid provider types" do
      changeset =
        cast({%{}, %{provider_type: :any}}, %{provider_type: "invalid"}, [:provider_type])

      result = Validations.validate_provider_type(changeset)
      refute result.valid?
      assert {"must be one of: faraday, trestle", []} = result.errors[:provider_type]
    end
  end

  describe "validate_status/1" do
    test "accepts success status" do
      changeset = cast({%{}, %{status: :any}}, %{status: "success"}, [:status])
      result = Validations.validate_status(changeset)
      assert result.valid?
    end

    test "accepts error status" do
      changeset = cast({%{}, %{status: :any}}, %{status: "error"}, [:status])
      result = Validations.validate_status(changeset)
      assert result.valid?
    end

    test "rejects invalid status" do
      changeset = cast({%{}, %{status: :any}}, %{status: "invalid"}, [:status])
      result = Validations.validate_status(changeset)
      refute result.valid?
      assert {"must be either: success, error", []} = result.errors[:status]
    end
  end
end
