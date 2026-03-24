defmodule WaltUi.Search do
  @moduledoc """
  This module is for handling search results
  from Typesense, formatting them into usable structs
  """
  use Appsignal.Instrumentation.Decorators

  require Logger

  alias WaltUi.Contacts
  alias WaltUi.Projections.Contact

  def new_search_all_by_user(user_id, query, opts \\ []) do
    request = new_format_multi_search_req(user_id, query, opts)

    case ExTypesense.multi_search(request) do
      {:ok, %{results: results}} ->
        new_format_search_results(results)

      error ->
        error
    end
  end

  @spec new_format_search_results(map()) :: list(Contact.t())
  def new_format_search_results(results) do
    hd(results)
  end

  def build_filter_by(user_id, opts) do
    base_filter = "user_id: #{user_id}"

    # Handle regular filters
    filter_with_fields =
      opts
      |> Keyword.get(:filter_by, [])
      |> Enum.reduce(base_filter, fn %{field: key, value: value}, acc ->
        acc <> " && #{key}: #{value}"
      end)

    # Handle location filter if present
    case Keyword.get(opts, :location) do
      {lat, lng, distance} ->
        filter_with_fields <> " && location:(#{lat}, #{lng}, #{distance})"

      nil ->
        filter_with_fields
    end
  end

  # This is really rudeimentary right now, and assumes only one order_by, when we can do multiple.
  def build_order_by(opts) do
    order_by = Keyword.get(opts, :order_by, [])

    case order_by do
      [] ->
        "ptt:desc"

      _ ->
        Enum.map_join(order_by, ",", fn %{field: key, direction: direction} ->
          "#{key}:#{direction}"
        end)
    end
  end

  defp new_format_multi_search_req(user_id, query, opts) do
    filter_by = build_filter_by(user_id, opts)
    order_by = build_order_by(opts)

    [
      %{
        collection: "contacts",
        q: query,
        query_by: "first_name, last_name, email, city, state, zip, tags",
        filter_by: filter_by,
        prioritize_exact_match: false,
        sort_by: order_by,
        page: Keyword.get(opts, :page, 1),
        per_page: Keyword.get(opts, :per_page, 30)
      }
    ]
  end

  # Kept for backwards compatibility with mobile apps.
  def search_all_by_user(user_id, query, opts \\ []) do
    request = format_multi_search_req(user_id, query, opts)

    case ExTypesense.multi_search(request) do
      {:ok, %{results: results}} -> format_search_results(results)
      error -> error
    end
  end

  @spec format_search_results(map()) :: list(Contact.t())
  def format_search_results(results) do
    results
    |> get_contact_ids()
    |> Contacts.get_contacts_in_id_list()
    |> tap(&Logger.info("Search queried #{length(&1)} contacts from IDs"))
    |> merge_contacts_with_results(results)
    |> sort_by_search_score()
  end

  defp format_multi_search_req(user_id, query, opts) do
    [
      %{
        collection: "contacts",
        q: query,
        query_by: "first_name, last_name, email",
        filter_by: "user_id: '#{user_id}'",
        order_by: "ptt",
        page: Keyword.get(opts, :page, 1),
        per_page: Keyword.get(opts, :per_page, 30)
      },
      %{
        collection: "notes",
        q: query,
        query_by: "note",
        filter_by: "user_id: '#{user_id}'",
        page: Keyword.get(opts, :page, 1),
        per_page: Keyword.get(opts, :per_page, 30)
      }
    ]
  end

  # returns a list of contact ids from
  # a Typesense multisearch
  defp get_contact_ids(results) do
    results
    |> search_hits_by_type()
    |> tap(&log_hits_by_type/1)
    |> search_contact_ids()
    |> Enum.uniq()
    |> tap(&Logger.info("Search matched #{length(&1)} contact IDs"))
  end

  defp log_hits_by_type(hits_by_type_map) do
    contacts =
      Map.get_lazy(hits_by_type_map, "contacts", fn ->
        Logger.warning("No contact hits in result")
        []
      end)

    notes =
      Map.get_lazy(hits_by_type_map, "notes", fn ->
        Logger.warning("No note hits in result")
        []
      end)

    Logger.info("Search found #{length(contacts)} contacts")
    Logger.info("Search found #{length(notes)} notes")
  end

  defp merge_contacts_with_results(contacts, results) do
    hits =
      results
      |> search_hits_by_type()
      |> search_by_contact_id()

    Enum.map(contacts, fn contact ->
      Map.put(contact, :search, Map.get(hits, contact.id))
    end)
  end

  # organizes the search results by the collection type
  # eg notes, contacts, helpful since their contact id is named differently
  defp search_hits_by_type(results) do
    Enum.reduce(results, %{}, fn result, acc ->
      collection =
        result
        |> get_in([:request_params, :collection_name])
        |> format_collection_name()

      Map.put(acc, collection, result.hits)
    end)
  end

  defp format_collection_name(name) do
    name
    |> to_string()
    |> String.split("_")
    |> List.first()
    |> String.to_atom()
  end

  # retuns a list of contact ids from
  # a multi search result set
  defp search_contact_ids(hits) do
    by_id =
      Enum.reduce(hits.contacts, [], fn contact, acc ->
        [get_in(contact, [:document, :id]) | acc]
      end)

    Enum.reduce(hits.notes, by_id, fn note, acc ->
      [get_in(note, [:document, :contact_id]) | acc]
    end)
  end

  # reorganizes the search results by unique contact id
  defp search_by_contact_id(hits) do
    by_id =
      Enum.reduce(hits.contacts, %{}, fn contact, acc ->
        id = get_in(contact, [:document, :id])
        item = format_search_item(contact)
        append_search_to_contact_id(acc, id, item)
      end)

    Enum.reduce(hits.notes, by_id, fn note, acc ->
      id = get_in(note, [:document, :contact_id])
      item = format_search_item(note)
      append_search_to_contact_id(acc, id, item)
    end)
  end

  # formats the nested search property for the contact
  defp format_search_item(item) do
    list =
      Enum.map(item.highlights, fn highlights ->
        Map.put(highlights, "score", item.text_match)
      end)

    %{"highlights" => list}
  end

  # handles merging search results for the same contact
  # sorts highest score first
  defp append_search_to_contact_id(acc, id, search) do
    Map.merge(acc, %{id => search}, fn _key, v1, v2 ->
      merged = v1["highlights"] ++ v2["highlights"]
      sorted = Enum.sort(merged, &(Map.get(&1, "score") >= Map.get(&2, "score")))

      %{"highlights" => sorted}
    end)
  end

  defp sort_by_search_score(contacts) do
    Enum.sort_by(
      contacts,
      fn contact ->
        contact.search
        |> Map.get("highlights")
        |> List.first()
        |> Map.get(["score"])
      end,
      :desc
    )
  end
end
