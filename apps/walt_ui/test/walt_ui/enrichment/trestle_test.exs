defmodule WaltUi.Enrichment.TrestleTest do
  use ExUnit.Case
  use Mimic

  alias WaltUi.Enrichment.Trestle
  alias WaltUi.Enrichment.Trestle.Http

  setup :verify_on_exit!

  setup do
    # Save original client config
    original_client = Application.get_env(:walt_ui, WaltUi.Trestle)[:client]

    # Set client to Http module for testing
    Application.put_env(:walt_ui, WaltUi.Trestle, client: WaltUi.Enrichment.Trestle.Client)

    on_exit(fn ->
      # Restore original client config
      current_config = Application.get_env(:walt_ui, WaltUi.Trestle, [])
      new_config = Keyword.put(current_config, :client, original_client)
      Application.put_env(:walt_ui, WaltUi.Trestle, new_config)
    end)

    :ok
  end

  describe "search_by_phone/2" do
    test "returns error with short phone number" do
      assert {:error, "Invalid phone number format"} = Trestle.search_by_phone("123")
    end

    test "returns error with long phone number" do
      # This should fail validation before making HTTP request
      # The TenDigitPhone module should reject this
      assert {:error, "Invalid phone number format"} = Trestle.search_by_phone("123456789012")
    end

    test "returns successfully with valid phone number" do
      expect(Http, :search_by_phone, fn _, _ -> {:ok, %{"phone_number" => "+15555555555"}} end)

      assert {:ok, _} = Trestle.search_by_phone("555-555-5555")
    end

    test "returns successfully with valid phone number without dashes" do
      expect(Http, :search_by_phone, fn _, _ -> {:ok, %{"phone_number" => "+15555555555"}} end)

      assert {:ok, _} = Trestle.search_by_phone("5555555555")
    end

    test "formats phone number correctly and removes country code" do
      expect(Http, :search_by_phone, fn phone, opts ->
        assert phone == "5555555555"
        assert Keyword.get(opts, :name_hint) == nil
        {:ok, %{"phone_number" => "+15555555555"}}
      end)

      assert {:ok, _} = Trestle.search_by_phone("15555555555")
    end

    test "handles phone number with +1 country code" do
      expect(Http, :search_by_phone, fn phone, opts ->
        assert phone == "5555555555"
        assert Keyword.get(opts, :name_hint) == nil
        {:ok, %{"phone_number" => "+15555555555"}}
      end)

      assert {:ok, _} = Trestle.search_by_phone("+15555555555")
    end

    test "passes name hint when provided" do
      expect(Http, :search_by_phone, fn phone, opts ->
        assert phone == "5555555555"
        assert Keyword.get(opts, :name_hint) == "John Doe"
        {:ok, %{"phone_number" => "+15555555555"}}
      end)

      assert {:ok, _} = Trestle.search_by_phone("5555555555", name_hint: "John Doe")
    end

    test "sanitizes name hint by removing emojis and trimming" do
      expect(Http, :search_by_phone, fn phone, opts ->
        assert phone == "5555555555"
        assert Keyword.get(opts, :name_hint) == "John Doe"
        {:ok, %{"phone_number" => "+15555555555"}}
      end)

      assert {:ok, _} = Trestle.search_by_phone("5555555555", name_hint: "  John Doe 😊  ")
    end

    test "handles nil name hint" do
      expect(Http, :search_by_phone, fn phone, opts ->
        assert phone == "5555555555"
        assert Keyword.get(opts, :name_hint) == nil
        {:ok, %{"phone_number" => "+15555555555"}}
      end)

      assert {:ok, _} = Trestle.search_by_phone("5555555555", name_hint: nil)
    end
  end
end
