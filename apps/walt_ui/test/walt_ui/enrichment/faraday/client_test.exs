defmodule WaltUi.Enrichment.Faraday.ClientTest do
  use Repo.DataCase, async: true
  use Mimic

  import WaltUi.Factory

  alias WaltUi.Enrichment.Faraday.Client
  alias WaltUi.Enrichment.Faraday.Http

  describe "fetch_contact/1" do
    test "sends formatted request over HTTP" do
      data =
        build(:provider_endato,
          email: "foo@bar.org",
          city: "Fooville",
          first_name: "Foo",
          last_name: "Bar",
          phone: "+1(555)123-1234",
          state: "OH",
          street_1: "123 Main St",
          street_2: "Unit 1",
          zip: "43113"
        )

      expect(Http, :fetch_contact, fn req ->
        assert %{
                 city: "Fooville",
                 email: "foo@bar.org",
                 house_number_and_street: "123 Main St Unit 1",
                 person_first_name: "Foo",
                 person_last_name: "Bar",
                 phone: "5551231234",
                 postcode: "43113",
                 state: "OH"
               } = req

        {:ok, :mock_response}
      end)

      assert {:ok, _} = Client.fetch_contact(data)
    end

    test "sanitizes name inputs" do
      data =
        build(:provider_endato, first_name: "😭 First", last_name: "Last 🖖", phone: "5551231234")

      expect(Http, :fetch_contact, fn req ->
        assert %{person_first_name: "First", person_last_name: "Last"} = req
        {:ok, :mock_response}
      end)

      assert {:ok, _} = Client.fetch_contact(data)
    end

    test "returns error if request cannot be formatted" do
      data = build(:provider_endato, phone: nil)
      reject(&Http.fetch_contact/1)
      assert {:error, "Phone is required"} = Client.fetch_contact(data)
    end
  end

  describe "extract_ptt/1" do
    test "returns ptt value" do
      resp = %{"fdy_outcome_2cac2e5e_27d4_4045_99ef_0338f007b8e6_propensity_probability" => 0.42}
      assert {:ok, 0.42} = Client.extract_ptt(resp)
    end

    test "returns error if not ptt found" do
      assert {:error, :no_ptt} = Client.extract_ptt(%{})
    end
  end
end
