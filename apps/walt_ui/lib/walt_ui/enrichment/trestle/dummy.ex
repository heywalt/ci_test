defmodule WaltUi.Enrichment.Trestle.Dummy do
  @moduledoc """
  A dummy implementation of the Trestle API for testing.
  """

  @behaviour WaltUi.Enrichment.Trestle

  @impl true
  def search_by_phone("5555555555", _opts) do
    {:ok,
     %{
       "id" => "550e8400-e29b-41d4-a716-446655440000",
       "phone_number" => "+15555555555",
       "is_valid" => true,
       "country_calling_code" => "+1",
       "line_type" => "Mobile",
       "carrier" => "Verizon Wireless",
       "is_prepaid" => false,
       "is_commercial" => false,
       "owners" => [
         %{
           "type" => "person",
           "id" => "person-123",
           "name" => %{
             "first" => "John",
             "middle" => "Michael",
             "last" => "Doe"
           },
           "age_range" => %{
             "min" => 30,
             "max" => 40
           },
           "gender" => "Male",
           "emails" => [
             %{
               "email" => "john.doe@example.com",
               "is_valid" => true,
               "first_seen" => "2020-01-01",
               "last_seen" => "2024-01-01"
             }
           ],
           "addresses" => [
             %{
               "type" => "current",
               "house_number" => "123",
               "street_prefix" => nil,
               "street_name" => "Main",
               "street_type" => "St",
               "street_suffix" => nil,
               "unit_type" => nil,
               "unit_number" => nil,
               "city" => "Anytown",
               "state" => "CA",
               "zip" => "12345",
               "zip4" => "6789",
               "is_deliverable" => true,
               "first_seen" => "2021-01-01",
               "last_seen" => "2024-01-01"
             }
           ]
         }
       ],
       "error" => nil,
       "warnings" => []
     }}
  end

  def search_by_phone("1111111111", _opts) do
    {:ok,
     %{
       "id" => nil,
       "phone_number" => "+11111111111",
       "is_valid" => false,
       "country_calling_code" => "+1",
       "line_type" => nil,
       "carrier" => nil,
       "is_prepaid" => nil,
       "is_commercial" => nil,
       "owners" => [],
       "error" => %{
         "message" => "Phone number not found",
         "code" => "NOT_FOUND"
       },
       "warnings" => ["Invalid Input"]
     }}
  end

  def search_by_phone(_phone, opts) do
    # Return a generic response with name hint if provided
    name_hint = Keyword.get(opts, :name_hint)

    {:ok,
     %{
       "id" => "generic-550e8400-e29b-41d4-a716-446655440000",
       "phone_number" => "+10000000000",
       "is_valid" => true,
       "country_calling_code" => "+1",
       "line_type" => "Mobile",
       "carrier" => "Unknown Carrier",
       "is_prepaid" => false,
       "is_commercial" => false,
       "owners" => [
         %{
           "type" => "person",
           "id" => "person-generic",
           "name" => parse_name_hint(name_hint),
           "age_range" => nil,
           "gender" => nil,
           "emails" => [],
           "addresses" => []
         }
       ],
       "error" => nil,
       "warnings" => []
     }}
  end

  defp parse_name_hint(nil) do
    %{
      "first" => "Unknown",
      "middle" => nil,
      "last" => "Person"
    }
  end

  defp parse_name_hint(name_hint) do
    parts = String.split(name_hint, " ")

    case parts do
      [first] ->
        %{"first" => first, "middle" => nil, "last" => nil}

      [first, last] ->
        %{"first" => first, "middle" => nil, "last" => last}

      [first, middle | rest] ->
        %{"first" => first, "middle" => middle, "last" => Enum.join(rest, " ")}
    end
  end
end
