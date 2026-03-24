defmodule CQRS.Enrichments.Commands.ResetTest do
  use ExUnit.Case, async: true

  alias CQRS.Enrichments.Commands.Reset

  describe "new/1" do
    test "creates command with provided timestamp" do
      timestamp = NaiveDateTime.utc_now()
      id = Ecto.UUID.generate()

      attrs = %{
        id: id,
        timestamp: timestamp
      }

      command = Reset.new(attrs)

      assert command.id == id
      assert command.timestamp == timestamp
    end

    test "creates command with generated timestamp when not provided" do
      id = Ecto.UUID.generate()
      attrs = %{id: id}

      command = Reset.new(attrs)

      assert command.id == id
      assert %NaiveDateTime{} = command.timestamp
    end
  end

  describe "CQRS.Certifiable" do
    test "validates successfully with valid data" do
      command = Reset.new(%{id: Ecto.UUID.generate()})
      assert :ok = CQRS.Certifiable.certify(command)
    end

    test "fails validation when id is nil" do
      command = Reset.new(%{id: Ecto.UUID.generate()})
      command_with_nil_id = %{command | id: nil}

      assert {:error, errors} = CQRS.Certifiable.certify(command_with_nil_id)
      assert Keyword.has_key?(errors, :id)
    end

    test "fails validation when id is invalid" do
      command = Reset.new(%{id: 123})

      assert {:error, errors} = CQRS.Certifiable.certify(command)
      assert {"is invalid", _} = errors[:id]
    end

    test "fails validation when timestamp is nil" do
      command = Reset.new(%{id: Ecto.UUID.generate()})
      command_with_nil_timestamp = %{command | timestamp: nil}

      assert {:error, errors} = CQRS.Certifiable.certify(command_with_nil_timestamp)
      assert Keyword.has_key?(errors, :timestamp)
    end
  end
end
