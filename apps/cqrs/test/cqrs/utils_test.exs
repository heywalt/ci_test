defmodule CQRS.UtilsTest do
  use ExUnit.Case, async: true

  alias CQRS.Utils

  describe "string_to_atom/1" do
    test "converts binary to atom" do
      assert Utils.string_to_atom("test") == :test
    end

    test "passes atom through" do
      assert Utils.string_to_atom(:test) == :test
    end
  end

  describe "atom_map/1" do
    test "converts string keys to atom keys" do
      assert Utils.atom_map(%{"key" => "value"}) == %{key: "value"}
    end

    test "passes atom keys through" do
      assert Utils.atom_map(%{key: "value"}) == %{key: "value"}
    end
  end

  describe "get/3" do
    test "returns value when key exists as atom" do
      map = %{name: "John", age: 30}
      assert Utils.get(map, :name) == "John"
      assert Utils.get(map, :age) == 30
    end

    test "returns value when key exists as string" do
      map = %{"name" => "John", "age" => 30}
      assert Utils.get(map, :name) == "John"
      assert Utils.get(map, :age) == 30
    end

    test "returns nil default when key doesn't exist and no default provided" do
      map = %{name: "John"}
      assert Utils.get(map, :missing) == nil
    end

    test "returns custom default when key doesn't exist" do
      map = %{name: "John"}
      assert Utils.get(map, :emails, []) == []
      assert Utils.get(map, :age, 0) == 0
      assert Utils.get(map, :city, "Unknown") == "Unknown"
    end

    test "prefers atom key over string key when both exist" do
      map = %{:name => "Atom Name", "name" => "String Name"}
      assert Utils.get(map, :name) == "Atom Name"
    end

    test "handles nested maps correctly" do
      map = %{
        :user => %{name: "John", age: 30},
        "address" => %{"city" => "NYC", "zip" => "10001"}
      }

      assert Utils.get(map, :user) == %{name: "John", age: 30}
      assert Utils.get(map, :address) == %{"city" => "NYC", "zip" => "10001"}
    end

    test "handles list values correctly" do
      map = %{
        "emails" => ["john@example.com", "john.doe@example.com"],
        :phones => ["555-1234", "555-5678"]
      }

      assert Utils.get(map, :emails) == ["john@example.com", "john.doe@example.com"]
      assert Utils.get(map, :phones) == ["555-1234", "555-5678"]
      assert Utils.get(map, :addresses, []) == []
    end

    test "handles nil and false values correctly" do
      map = %{:active => false, "deleted_at" => nil}
      assert Utils.get(map, :active) == false
      assert Utils.get(map, :deleted_at) == nil
      # nil is a value, not missing
      assert Utils.get(map, :deleted_at, "default") == nil
    end

    test "handles empty map" do
      assert Utils.get(%{}, :anything) == nil
      assert Utils.get(%{}, :anything, "default") == "default"
    end
  end
end
