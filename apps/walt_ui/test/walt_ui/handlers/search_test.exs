defmodule WaltUi.Handlers.SearchTest do
  use WaltUi.CqrsCase
  use Mimic

  alias CQRS.Leads.Events
  alias WaltUi.Handlers.Search

  setup :verify_on_exit!

  describe "handle/2 with LeadCreated" do
    test "indexes new document in TypeSense" do
      event = %Events.LeadCreated{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        phone: "1234567890",
        timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      }

      expect(ExTypesense, :index_document, fn doc ->
        assert doc.collection_name == "contacts"
        assert doc.id == event.id
        assert doc.first_name == "John"
        assert doc.last_name == "Doe"
        assert doc.email == "john@example.com"
        assert doc.phone == "1234567890"
        assert doc.inserted_at
        assert doc.updated_at

        {:ok, %{}}
      end)

      assert :ok = Search.handle(event, %{})
    end
  end

  describe "handle/2 with LeadUnified" do
    test "updates enrichment fields in TypeSense document" do
      event = %Events.LeadUnified{
        id: Ecto.UUID.generate(),
        enrichment_id: Ecto.UUID.generate(),
        city: "Austin",
        ptt: 85,
        state: "TX",
        street_1: "123 Main St",
        street_2: "Apt 4B",
        zip: "78701",
        timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      }

      expect(ExTypesense, :update_document, fn doc ->
        assert doc.collection_name == "contacts"
        assert doc.id == event.id
        assert doc.city == "Austin"
        assert doc.ptt == 85
        assert doc.state == "TX"
        assert doc.street_1 == "123 Main St"
        assert doc.street_2 == "Apt 4B"
        assert doc.zip == "78701"
        assert doc.updated_at

        {:ok, %{}}
      end)

      assert :ok = Search.handle(event, %{})
    end
  end

  describe "handle/2 with LeadUpdated" do
    test "updates contact attributes in TypeSense document" do
      event = %Events.LeadUpdated{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        attrs: %{
          "first_name" => "Jane",
          "last_name" => "Smith",
          "email" => "jane@example.com"
        },
        metadata: [],
        timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      }

      expect(ExTypesense, :update_document, fn doc ->
        assert doc.collection_name == "contacts"
        assert doc.id == event.id
        assert doc["first_name"] == "Jane"
        assert doc["last_name"] == "Smith"
        assert doc["email"] == "jane@example.com"
        assert doc.updated_at

        {:ok, %{}}
      end)

      assert :ok = Search.handle(event, %{})
    end

    test "adds location field when string lat/lng are present" do
      event = %Events.LeadUpdated{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        attrs: %{
          "latitude" => "33.4829784",
          "longitude" => "-86.7819516"
        },
        metadata: [],
        timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      }

      expect(ExTypesense, :update_document, fn doc ->
        assert doc.collection_name == "contacts"
        assert doc.id == event.id
        assert doc["latitude"] == "33.4829784"
        assert doc["longitude"] == "-86.7819516"
        assert doc.location == [33.4829784, -86.7819516]
        assert doc.updated_at

        {:ok, %{}}
      end)

      assert :ok = Search.handle(event, %{})
    end

    test "adds location field when Decimal lat/lng are present" do
      event = %Events.LeadUpdated{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        attrs: %{
          latitude: Decimal.new("33.4829784"),
          longitude: Decimal.new("-86.7819516")
        },
        metadata: [],
        timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      }

      expect(ExTypesense, :update_document, fn doc ->
        assert doc.collection_name == "contacts"
        assert doc.id == event.id
        assert doc.latitude == Decimal.new("33.4829784")
        assert doc.longitude == Decimal.new("-86.7819516")
        assert doc.location == [33.4829784, -86.7819516]
        assert doc.updated_at

        {:ok, %{}}
      end)

      assert :ok = Search.handle(event, %{})
    end

    test "does not add location field when lat/lng are invalid strings" do
      event = %Events.LeadUpdated{
        id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        attrs: %{
          "latitude" => "invalid",
          "longitude" => "also_invalid"
        },
        metadata: [],
        timestamp: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)
      }

      expect(ExTypesense, :update_document, fn doc ->
        assert doc.collection_name == "contacts"
        assert doc.id == event.id
        assert doc["latitude"] == "invalid"
        assert doc["longitude"] == "also_invalid"
        refute Map.has_key?(doc, :location)
        assert doc.updated_at

        {:ok, %{}}
      end)

      assert :ok = Search.handle(event, %{})
    end
  end

  describe "handle/2 with LeadDeleted" do
    test "removes document from TypeSense" do
      event = %Events.LeadDeleted{
        id: Ecto.UUID.generate()
      }

      expect(ExTypesense, :delete_document, fn collection, id ->
        assert collection == "contacts"
        assert id == event.id

        {:ok, %{}}
      end)

      assert :ok = Search.handle(event, %{})
    end
  end
end
