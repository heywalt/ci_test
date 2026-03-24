defmodule WaltUi.MCP.Tools.SearchContacts do
  @moduledoc """
  Search for contacts by name, email, or phone number.
  Returns matching contacts with enrichment data for AI analysis.
  """

  use Anubis.Server.Component, type: :tool

  import Ecto.Query

  alias Repo
  alias WaltUi.Projections.Contact
  alias WaltUi.Projections.Enrichment

  schema do
    field :query, :string, required: true, description: "Search term (name, email, or phone)"
    field :limit, :integer, default: 10, description: "Maximum number of results to return"
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    query = Map.get(params, "query", "")
    limit = Map.get(params, "limit", 10)

    require Logger
    Logger.info("SearchContacts called with query: #{inspect(query)}, limit: #{limit}")

    if is_nil(user_id) do
      {:error, "user_id is required in context"}
    else
      contacts = search_contacts(user_id, query, limit)
      Logger.info("SearchContacts found #{length(contacts)} contacts")
      {:ok, %{"contacts" => format_contacts_with_enrichment(contacts)}}
    end
  end

  defp search_contacts(user_id, query, limit) do
    search_term = "%#{String.downcase(query)}%"
    looks_like_phone = String.match?(query, ~r/\d/)

    # Check if query looks like "FirstName LastName"
    name_parts = String.split(String.trim(query), ~r/\s+/)

    base_query =
      from(c in Contact,
        where: c.user_id == ^user_id,
        order_by: [desc: c.updated_at],
        limit: ^limit,
        preload: [:notes, :tags]
      )

    base_query
    |> apply_name_search(name_parts, search_term)
    |> then(fn q ->
      if looks_like_phone do
        where(q, [c], c.phone == ^query or c.standard_phone == ^query)
      else
        q
      end
    end)
    |> Repo.all()
  end

  defp apply_name_search(query, [first_part, last_part], _search_term) do
    # Two-word query: try matching as "FirstName LastName"
    first_term = "%#{String.downcase(first_part)}%"
    last_term = "%#{String.downcase(last_part)}%"

    where(
      query,
      [c],
      (fragment("LOWER(?) LIKE ?", c.first_name, ^first_term) and
         fragment("LOWER(?) LIKE ?", c.last_name, ^last_term)) or
        fragment("LOWER(?) LIKE ?", c.email, ^first_term)
    )
  end

  defp apply_name_search(query, _name_parts, search_term) do
    # Single word or 3+ words: use original fuzzy search
    where(
      query,
      [c],
      fragment("LOWER(?) LIKE ?", c.first_name, ^search_term) or
        fragment("LOWER(?) LIKE ?", c.last_name, ^search_term) or
        fragment("LOWER(?) LIKE ?", c.email, ^search_term)
    )
  end

  defp format_contacts_with_enrichment(contacts) do
    Enum.map(contacts, fn contact ->
      enrichment = get_enrichment(contact.enrichment_id)

      %{
        "id" => contact.id,
        "name" => format_name(contact),
        "email" => contact.email,
        "phone" => contact.phone,
        "address" => format_address(contact),
        "ptt" => contact.ptt,
        "is_favorite" => contact.is_favorite,
        "last_updated" => contact.updated_at,
        "notes_count" => length(contact.notes),
        "tags" => Enum.map(contact.tags, & &1.name),
        "enrichment" => format_enrichment(enrichment)
      }
    end)
  end

  defp get_enrichment(nil), do: nil

  defp get_enrichment(enrichment_id) do
    Repo.get(Enrichment, enrichment_id)
  end

  defp format_enrichment(nil), do: %{}

  defp format_enrichment(enrichment) do
    %{
      # Key home buying/selling indicators
      "homeowner_status" => enrichment.homeowner_status,
      "length_of_residence" => enrichment.length_of_residence,
      "mortgage_liability" => enrichment.mortgage_liability,
      "percent_equity" => enrichment.percent_equity,
      "home_equity_loan_date" => enrichment.home_equity_loan_date,
      "latest_mortgage_date" => enrichment.latest_mortgage_date,
      "target_home_market_value" => enrichment.target_home_market_value,

      # Life events that trigger moves
      "marital_status" => enrichment.marital_status,
      "date_newly_married" => enrichment.date_newly_married,
      "date_newly_single" => enrichment.date_newly_single,
      "date_empty_nester" => enrichment.date_empty_nester,
      "date_retired" => enrichment.date_retired,
      "has_children_in_household" => enrichment.has_children_in_household,
      "number_of_children" => enrichment.number_of_children,

      # Financial indicators
      "household_income" => enrichment.household_income,
      "income_change_date" => enrichment.income_change_date,
      "net_worth" => enrichment.net_worth,
      "liquid_resources" => enrichment.liquid_resources,

      # Property details
      "property_type" => enrichment.property_type,
      "number_of_bedrooms" => enrichment.number_of_bedrooms,
      "year_built" => enrichment.year_built,
      "living_area" => enrichment.living_area,
      "lot_area" => enrichment.lot_area,
      "average_commute_time" => enrichment.average_commute_time
    }
  end

  defp format_name(contact) do
    [contact.first_name, contact.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.trim()
  end

  defp format_address(contact) do
    [contact.street_1, contact.street_2, contact.city, contact.state, contact.zip]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
    |> String.trim()
  end
end
