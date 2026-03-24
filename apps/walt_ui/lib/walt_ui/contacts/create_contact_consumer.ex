defmodule WaltUi.Contacts.CreateContactsConsumer do
  @moduledoc false

  use Broadway

  alias Broadway.Message
  alias WaltUi.Contacts
  alias WaltUi.ContactTags
  alias WaltUi.Tags

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      context: config(:context, %{}),
      producer: [
        module: {config(:producer, BroadwayCloudPubSub.Producer), config(:producer_options, [])}
      ],
      processors: [default: [concurrency: 10]],
      batchers: [
        bulk_create: [batch_size: config(:batch_size), batch_timeout: 1_000],
        noop: [batch_size: config(:batch_size), batch_timeout: 1_000]
      ]
    )
  end

  @impl true
  def handle_message(_, %Message{} = message, _) do
    case Jason.decode(message.data, keys: :atoms) do
      {:ok, decoded} ->
        message
        |> Message.put_data(to_attrs(decoded))
        |> Message.put_batcher(:bulk_create)

      _ ->
        Message.put_batcher(message, :noop)
    end
  end

  @impl true
  def handle_batch(:bulk_create, messages, _, ctx) do
    bulk_create_fun = Map.get(ctx, :bulk_create_fun, &Contacts.bulk_create/1)
    Logger.info("Attempting to import #{length(messages)} contacts")

    contact_attrs = Enum.map(messages, & &1.data)

    # Create contacts first
    bulk_create_fun.(contact_attrs)

    # Process tags for contacts that have them
    process_tags_for_contacts(contact_attrs)

    messages
  rescue
    error ->
      Logger.error("Exception during bulk creation of contacts", details: inspect(error))
      messages
  end

  def handle_batch(:noop, messages, _, _) do
    Logger.warning("Did not create #{length(messages)} contacts")
    messages
  end

  defp process_tags_for_contacts(contact_attrs) do
    contact_attrs
    |> Enum.filter(&has_tags?/1)
    |> Enum.each(&process_contact_tags/1)
  end

  defp has_tags?(contact_attrs) do
    tags = Map.get(contact_attrs, :tags)
    tags && String.trim(tags) != ""
  end

  defp process_contact_tags(contact_attrs) do
    user_id = Map.get(contact_attrs, :user_id)
    remote_source = Map.get(contact_attrs, :remote_source)
    remote_id = Map.get(contact_attrs, :remote_id)
    tags_string = Map.get(contact_attrs, :tags)

    # Generate the same deterministic UUID used by CQRS
    contact_id = UUID.uuid5(:oid, "#{user_id}:#{remote_source}:#{remote_id}")

    # Parse and process tags
    tags_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.each(fn tag_name ->
      with {:ok, tag} <- Tags.find_or_create_tag(user_id, tag_name, default_tag_color()),
           {:ok, _contact_tag} <- ContactTags.find_or_create(user_id, contact_id, tag.id) do
        :ok
      else
        {:error, error} ->
          Logger.warning("Failed to process tag '#{tag_name}' for contact #{contact_id}",
            error: error
          )
      end
    end)
  end

  defp default_tag_color, do: "grey"

  defp config(key, default \\ nil) do
    :walt_ui
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end

  defp to_attrs(contact) do
    contact
    |> Enum.reject(fn {_key, val} -> is_nil(val) end)
    |> Map.new()
  end
end
