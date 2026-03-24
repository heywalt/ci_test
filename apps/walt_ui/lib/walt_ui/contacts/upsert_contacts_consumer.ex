defmodule WaltUi.Contacts.UpsertContactsConsumer do
  @moduledoc false

  use Broadway

  alias Broadway.Message
  alias WaltUi.Contacts
  alias WaltUi.Projections.Contact

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      context: config(:context, %{}),
      producer: [
        module: {
          config(:producer, BroadwayCloudPubSub.Producer),
          config(:producer_options, [])
        }
      ],
      processors: [
        default: [
          concurrency: 10
        ]
      ],
      batchers: [
        create: config(:batcher_options, []),
        noop: config(:batcher_options, []),
        updated: config(:batcher_options, [])
      ]
    )
  end

  @impl true
  def handle_message(_processor, message, _ctx) do
    with {:ok, attrs} <- Jason.decode(message.data, keys: :atoms),
         attrs = normalize_attrs(attrs),
         %Contact{} = contact <-
           Contacts.get_contact(attrs.user_id, attrs.remote_source, attrs.remote_id),
         {:ok, _} <- CQRS.update_contact(contact, attrs) do
      Message.put_batcher(message, :updated)
    else
      nil ->
        message.data
        |> Jason.decode!(keys: :atoms)
        |> Enum.reject(fn {_key, val} -> is_nil(val) end)
        |> Map.new()
        |> then(&Message.put_data(message, &1))
        |> Message.put_batcher(:create)

      {:error, error} ->
        Logger.warning("Error handling message during bulk create/update",
          details: inspect(error)
        )

        Message.put_batcher(message, :noop)
    end
  end

  @impl true
  def handle_batch(:create, messages, _, ctx) do
    create_fn = Map.get(ctx, :create_fn, &Contacts.bulk_create/1)
    Enum.each(messages, fn msg -> create_fn.([msg.data]) end)

    messages
  rescue
    error ->
      Logger.error("Exception during contact creation", details: inspect(error))
      messages
  end

  def handle_batch(:updated, messages, _, _) do
    Logger.info("Updated #{length(messages)} contacts via bulk upsert")
    messages
  end

  def handle_batch(:noop, messages, _, _), do: messages

  defp config(key, default) do
    :walt_ui
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end

  defp normalize_attrs(attrs) do
    for {key, val} <- attrs, not is_nil(val), do: {key, val}, into: %{}
  end
end
