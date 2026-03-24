defmodule WaltUi.Enrichment.FaradayTest do
  use Repo.DataCase
  use Mimic

  alias WaltUi.Enrichment.Faraday
  alias WaltUi.Enrichment.Faraday.Http
  alias WaltUi.Projections.Contact

  setup :verify_on_exit!

  setup do
    # Use the real client instead of dummy
    original_client = Application.get_env(:walt_ui, WaltUi.Faraday)[:client]
    Application.put_env(:walt_ui, WaltUi.Faraday, client: WaltUi.Enrichment.Faraday.Client)

    on_exit(fn ->
      current_config = Application.get_env(:walt_ui, WaltUi.Faraday, [])
      new_config = Keyword.put(current_config, :client, original_client)
      Application.put_env(:walt_ui, WaltUi.Faraday, new_config)
    end)
  end

  describe "fetch_contact/1" do
    test "returns error with missing last name" do
      contact = %Contact{
        first_name: "Toto",
        email: "totowolf@example.com",
        phone: "123-456-7890"
      }

      assert {:error, "Last name is required"} = Faraday.fetch_contact(contact)
    end

    test "returns error with missing phone" do
      contact = %Contact{
        first_name: "Toto",
        last_name: "Wolf",
        email: "totowolf@example.com"
      }

      assert {:error, "Phone is required"} = Faraday.fetch_contact(contact)
    end

    test "returns successfully with valid contact" do
      contact = %Contact{
        first_name: "Toto",
        last_name: "Wolf",
        phone: "123-456-7890",
        email: "totowolf@example.com"
      }

      expect(Http, :fetch_contact, fn _ -> {:ok, "Stuff from Faraday"} end)

      assert {:ok, _} = Faraday.fetch_contact(contact)
    end
  end
end
