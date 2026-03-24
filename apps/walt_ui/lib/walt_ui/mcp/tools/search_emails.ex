defmodule WaltUi.MCP.Tools.SearchEmails do
  @moduledoc """
  Search for emails with a specific contact and return full email body content.
  Fetches email content in real-time from Gmail API for AI summarization.

  Can be called two ways:
  1. By contact_name: Searches for emails with that contact
  2. By message_id: Fetches a specific email by Gmail message ID
  """

  use Anubis.Server.Component, type: :tool

  require Logger

  alias WaltUi.Contacts
  alias WaltUi.ExternalAccounts
  alias WaltUi.Google.Gmail

  @max_limit 20
  @default_limit 5

  schema do
    field :contact_name, :string, description: "Contact name to search for emails with"

    field :message_id, :string,
      description: "Optional: Specific Gmail message ID to fetch directly"

    field :limit, :integer,
      default: @default_limit,
      description: "Maximum number of emails to return (default: 5, max: 20)"
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    contact_name = Map.get(params, "contact_name")
    message_id = Map.get(params, "message_id")
    limit = params |> Map.get("limit", @default_limit) |> min(@max_limit)

    Logger.info("SearchEmails called - contact: #{contact_name}, message_id: #{message_id}")

    with :ok <- validate_user_id(user_id),
         :ok <- validate_params(contact_name, message_id),
         {:ok, ea} <- get_external_account(user_id) do
      if message_id do
        fetch_single_email(ea, message_id)
      else
        search_contact_emails(ea, user_id, contact_name, limit)
      end
    end
  end

  defp validate_user_id(nil), do: {:error, "user_id is required in context"}
  defp validate_user_id(_user_id), do: :ok

  defp validate_params(nil, nil) do
    {:error, "Either contact_name or message_id is required"}
  end

  defp validate_params(_, _), do: :ok

  defp get_external_account(user_id) do
    case ExternalAccounts.for_user_id(user_id, :google) do
      nil -> {:error, "No Google account connected"}
      ea -> {:ok, ea}
    end
  end

  defp fetch_single_email(ea, message_id) do
    case Gmail.get_message_with_body(ea, message_id) do
      {:ok, email} ->
        formatted = format_email(email, ea.email)

        {:ok,
         %{
           "emails" => [formatted],
           "total_found" => 1
         }}

      {:error, reason} ->
        {:error, "Failed to fetch email: #{inspect(reason)}"}
    end
  end

  defp search_contact_emails(ea, user_id, contact_name, limit) do
    with {:ok, contact} <- find_contact(user_id, contact_name),
         {:ok, emails} <- search_and_fetch_emails(ea, contact, limit) do
      {:ok,
       %{
         "emails" => emails,
         "contact" => format_contact(contact),
         "total_found" => length(emails)
       }}
    end
  end

  defp find_contact(user_id, name) do
    case Contacts.search_by_name(user_id, name, limit: 5) do
      [] ->
        {:error, "No contacts found matching '#{name}'"}

      [contact] ->
        {:ok, contact}

      contacts ->
        names =
          Enum.map_join(contacts, ", ", &format_name/1)

        {:error, "Multiple contacts found matching '#{name}': #{names}. Please be more specific."}
    end
  end

  defp search_and_fetch_emails(ea, contact, limit) do
    contact_emails = get_contact_emails(contact)

    if Enum.empty?(contact_emails) do
      {:ok, []}
    else
      gmail_query = build_gmail_query(contact_emails)
      Logger.info("Gmail query: #{gmail_query}")

      with {:ok, message_response} <- Gmail.list_message_ids(ea, query: gmail_query),
           message_ids <- extract_message_ids(message_response, limit),
           emails <- fetch_messages_with_body(ea, message_ids) do
        formatted_emails = Enum.map(emails, &format_email(&1, ea.email))
        {:ok, formatted_emails}
      end
    end
  end

  defp get_contact_emails(contact) do
    primary = contact.email
    additional = (contact.emails || []) |> Enum.map(& &1["email"])

    [primary | additional]
    |> Enum.reject(fn email -> is_nil(email) or email == "" end)
    |> Enum.uniq()
  end

  defp build_gmail_query(emails) do
    emails
    |> Enum.flat_map(fn email -> ["from:#{email}", "to:#{email}"] end)
    |> Enum.join(" OR ")
  end

  defp extract_message_ids(%{"messages" => messages}, limit) when is_list(messages) do
    messages
    |> Enum.take(limit)
    |> Enum.map(& &1["id"])
  end

  defp extract_message_ids(_, _limit), do: []

  defp fetch_messages_with_body(ea, message_ids) do
    message_ids
    |> Enum.map(&Gmail.get_message_with_body(ea, &1))
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(fn {:ok, message} -> message end)
  end

  defp format_email(email, user_email) do
    direction = determine_direction(email, user_email)

    %{
      "id" => email.id,
      "thread_id" => email.thread_id,
      "subject" => email.subject,
      "from" => format_email_field(email.from),
      "to" => format_email_field(email.to),
      "date" => email.date,
      "direction" => direction,
      "body" => email.body,
      "message_link" => email.message_link
    }
  end

  defp determine_direction(%{from: from}, user_email) when from == user_email, do: "sent"
  defp determine_direction(_, _), do: "received"

  defp format_email_field(nil), do: nil
  defp format_email_field(email) when is_binary(email), do: email
  defp format_email_field([email | _]) when is_binary(email), do: email
  defp format_email_field(_), do: nil

  defp format_contact(contact) do
    %{
      "id" => contact.id,
      "name" => format_name(contact),
      "email" => contact.email
    }
  end

  defp format_name(contact) do
    [contact.first_name, contact.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> String.trim()
  end
end
