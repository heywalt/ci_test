defmodule WaltUi.Enrichment.EndatoJob do
  @moduledoc false

  use Oban.Worker, queue: :endato, max_attempts: 10

  require Logger

  alias CQRS.Enrichments.Commands.CompleteProviderEnrichment
  alias Repo.Types.TenDigitPhone
  alias WaltUi.Enrichment.Endato

  @impl true
  def perform(%{args: %{"event" => event}}) do
    attrs = for {key, val} <- event, do: {String.to_atom(key), val}, into: %{}
    Logger.metadata(event_id: attrs.id, module: __MODULE__)

    perform_enrichment(attrs)
  end

  defp endato_addresses(%{"person" => %{"address" => addr}}) do
    addr
    |> normalize_address()
    |> List.wrap()
  end

  defp endato_addresses(%{"person" => %{"addresses" => addrs}}) do
    Enum.map(addrs, &normalize_address/1)
  end

  defp endato_addresses(_), do: []

  defp endato_emails(%{"person" => %{"email" => nil}}), do: []
  defp endato_emails(%{"person" => %{"email" => email}}), do: [email]

  defp endato_emails(%{"person" => %{"emails" => emails}}) do
    emails
    |> Enum.map(& &1["email"])
    |> Enum.filter(& &1)
  end

  defp endato_emails(_else), do: []

  defp normalize_address(addr) do
    %{
      city: addr["city"],
      state: addr["state"],
      street_1: addr["street"],
      street_2: addr["unit"],
      zip: addr["zip"]
    }
  end

  defp to_int(int) when is_integer(int), do: int

  defp to_int(str) when is_binary(str) do
    String.to_integer(str)
  rescue
    _ -> nil
  end

  defp to_int(_other), do: nil

  # Enrichment processing functions
  defp perform_enrichment(attrs) do
    contact_data = normalize_contact_data(attrs.contact_data)

    if fetchable?(contact_data) do
      fetch(contact_data, attrs)
    else
      caller_id(contact_data, attrs)
    end
  end

  defp normalize_contact_data(contact_data) when is_map(contact_data) do
    # Handle both string and atom keys
    %{
      phone: contact_data["phone"] || contact_data[:phone],
      first_name: contact_data["first_name"] || contact_data[:first_name],
      last_name: contact_data["last_name"] || contact_data[:last_name],
      emails: contact_data["emails"] || contact_data[:emails] || [],
      addresses: contact_data["addresses"] || contact_data[:addresses] || []
    }
  end

  defp fetchable?(%{first_name: name}) when name in ["", nil], do: false
  defp fetchable?(%{last_name: name}) when name in ["", nil], do: false
  defp fetchable?(_contact_data), do: true

  defp fetch(contact_data, attrs) do
    # Convert contact_data to the format expected by Endato.fetch_contact
    fetch_attrs = %{
      id: attrs.id,
      phone: contact_data.phone,
      first_name: contact_data.first_name,
      last_name: contact_data.last_name,
      email: List.first(contact_data.emails)
    }

    case Endato.fetch_contact(fetch_attrs) do
      {:ok, %{"person" => _} = body} ->
        Logger.info("Found Endato enrichment via fetch")
        dispatch_completion(body, :fetch, attrs)

      {:ok, _no_match} ->
        Logger.info("Falling back to Endato caller ID")
        caller_id(contact_data, attrs)

      {:error, error} ->
        Logger.warning("Failed to fetch via Endato", details: inspect(error))
        caller_id(contact_data, attrs)
    end
  end

  defp caller_id(contact_data, attrs) do
    with {:ok, phone} <- TenDigitPhone.cast(contact_data.phone),
         {:ok, %{"person" => _} = body} <- Endato.search_by_phone(phone) do
      Logger.info("Found Endato enrichment via caller ID")
      dispatch_completion(body, :caller_id, attrs)
    else
      {:ok, _no_match} ->
        Logger.info("No Endato caller ID data found")
        dispatch_error_completion(attrs, %{reason: :no_data_found})
        :ok

      {:error, %{reason_atom: :bad_request}} ->
        Logger.info("Ignoring Endato enrichment", reason: :bad_request)
        dispatch_error_completion(attrs, %{reason: :bad_request})
        {:cancel, :bad_request}

      error ->
        Logger.warning("Failed to get Endato caller ID data", details: inspect(error))
        dispatch_error_completion(attrs, %{reason: elem(error, 1)})
        {:cancel, :unknown_error}
    end
  end

  defp dispatch_completion(body, source, attrs) do
    enrichment_data = %{
      addresses: endato_addresses(body),
      age: body |> get_in(["person", "age"]) |> to_int(),
      emails: endato_emails(body),
      first_name: get_in(body, ["person", "name", "firstName"]),
      last_name: get_in(body, ["person", "name", "lastName"]),
      phone:
        get_in(attrs, [:contact_data, :phone]) || get_in(attrs, [:contact_data, "phone"]) ||
          attrs[:phone]
    }

    quality_metadata = %{
      source: source
    }

    command =
      CompleteProviderEnrichment.new(%{
        id: attrs.id,
        provider_type: "endato",
        status: "success",
        enrichment_data: enrichment_data,
        quality_metadata: quality_metadata
      })

    case CQRS.dispatch(command) do
      :ok ->
        :ok

      {:error, error} ->
        Logger.warning("Failed to dispatch CompleteProviderEnrichment command",
          details: inspect(error)
        )

        {:error, :dispatch}
    end
  end

  defp dispatch_error_completion(attrs, error_data) do
    command =
      CompleteProviderEnrichment.new(%{
        id: attrs.id,
        provider_type: "endato",
        status: "error",
        error_data: error_data
      })

    case CQRS.dispatch(command) do
      :ok ->
        :ok

      {:error, error} ->
        Logger.warning("Failed to dispatch error CompleteProviderEnrichment command",
          details: inspect(error)
        )

        {:error, :dispatch}
    end
  end
end
