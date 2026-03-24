defmodule WaltUi.Google.Gmail do
  @moduledoc """
  A module for interacting with Google Gmail.
  """
  require Logger

  alias WaltUi.Contacts
  alias WaltUi.ExternalAccounts
  alias WaltUi.ExternalAccounts.ExternalAccount
  alias WaltUi.ExternalAccountsAuthHelper, as: Auth

  @doc """
  Syncs messages from Google Gmail.

  NOTE: Assumes that the ExternalAccount being passed in has the User preloaded.
  """
  @spec sync_messages(map()) :: list() | {:error, String.t()}
  def sync_messages(ea) do
    Logger.info("Starting Gmail Sync for #{inspect(ea.email)}")

    with {:ok, history_response} <- list_history(ea),
         message_ids <- get_latest_message_ids(history_response),
         messages <- fetch_and_format_messages(ea, message_ids) do
      processed_messages =
        messages
        |> categorize_messages(ea.email)
        |> filter_messages_with_contacts(ea)
        |> Enum.map(&format_date/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&Map.merge(&1, %{source: "google", user_id: ea.user_id}))
        |> Enum.map(&add_message_link/1)

      Logger.info("#{length(processed_messages)} / #{length(messages)} getting dispatched")

      # Dispatch the commands to create ContactInteractions for the new messages.
      Enum.each(processed_messages, &CQRS.create_correspondence/1)

      # Update the history ID for the ExternalAccount.
      update_gmail_history(ea)

      processed_messages
    else
      {:error, error} ->
        Logger.error("Failed to sync messages",
          error: inspect(error),
          external_account_id: ea.id
        )

        {:error, "Failed to sync messages: #{inspect(error)}"}
    end
  end

  def list_message_ids(ea, opts) do
    query = Keyword.get(opts, :query, "")
    page_token = Keyword.get(opts, :page_token, "")

    with {:ok, token} <- Auth.get_latest_token(ea) do
      token
      |> client()
      |> Tesla.get("/users/#{ea.email}/messages",
        query: %{
          q: query,
          pageToken: page_token
        }
      )
      |> handle_response()
    end
  end

  @spec set_initial_history_id(ExternalAccount.t()) :: {:ok, any()} | {:error, any()}
  def set_initial_history_id(ea) do
    with {:ok, %{"historyId" => history_id}} <- get_profile(ea) do
      ExternalAccounts.update(ea, %{gmail_history_id: history_id})
    end
  end

  @doc """
  Get the user's profile from Google. Necessary after creating the ExternalAccount, as we need to get
  the history ID from the profile, which tells us where to start from when fetching new messages.
  """
  @spec get_profile(ExternalAccount.t()) :: {:ok, any()} | {:error, any()}
  def get_profile(ea) do
    with {:ok, token} <- Auth.get_latest_token(ea) do
      token
      |> client()
      |> Tesla.get("/users/#{ea.email}/profile")
      |> handle_response()
    end
  end

  @doc """
  Given an ExternalAccount, we use the gmail_history_id to fetch new messages from Google from
  the point in time represented by the gmail_history_id.
  """
  @spec list_history(atom()) :: {:error, any()} | {:ok, any()}
  def list_history(ea) do
    with {:ok, token} <- Auth.get_latest_token(ea) do
      token
      |> client()
      |> Tesla.get("/users/#{ea.email}/history",
        query: %{
          startHistoryId: ea.gmail_history_id
        }
      )
      |> handle_response()
    end
  end

  @doc """
  Get a message from Google.
  """
  @spec get_message(ExternalAccount.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def get_message(ea, message_id) do
    with {:ok, token} <- Auth.get_latest_token(ea) do
      token
      |> client()
      |> Tesla.get("/users/#{ea.email}/messages/#{message_id}")
      |> handle_response()
    end
  end

  @doc """
  Fetches a message and extracts full content including body.
  Returns formatted map with all email details plus body content.
  """
  @spec get_message_with_body(ExternalAccount.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def get_message_with_body(ea, message_id) do
    with {:ok, message} <- get_message(ea, message_id) do
      formatted = format_message(message)
      body = extract_body(message)

      result =
        formatted
        |> Map.put(:body, body)
        |> add_message_link()

      {:ok, result}
    end
  end

  @doc """
  Extracts the email body from a Gmail message payload.
  Prefers text/plain content, falls back to text/html (with HTML tags stripped).
  """
  @spec extract_body(map()) :: String.t() | nil
  def extract_body(%{"payload" => payload}) do
    extract_body_from_payload(payload)
  end

  def extract_body(_), do: nil

  defp extract_body_from_payload(%{"body" => %{"data" => data}}) when is_binary(data) do
    decode_body(data)
  end

  defp extract_body_from_payload(%{"parts" => parts}) when is_list(parts) and parts != [] do
    find_body_in_parts(parts)
  end

  defp extract_body_from_payload(_), do: nil

  defp find_body_in_parts(parts) do
    # First try to find text/plain
    text_part = Enum.find(parts, &(get_mime_type(&1) == "text/plain"))

    # Fall back to text/html
    html_part = Enum.find(parts, &(get_mime_type(&1) == "text/html"))

    # Check for nested multipart structures
    nested_part = Enum.find(parts, &has_nested_parts?/1)

    cond do
      text_part && get_body_data(text_part) ->
        decode_body(get_body_data(text_part))

      html_part && get_body_data(html_part) ->
        html_part
        |> get_body_data()
        |> decode_body()
        |> strip_html()

      nested_part ->
        find_body_in_parts(nested_part["parts"])

      true ->
        nil
    end
  end

  defp get_mime_type(%{"mimeType" => mime_type}), do: mime_type
  defp get_mime_type(_), do: nil

  defp get_body_data(%{"body" => %{"data" => data}}), do: data
  defp get_body_data(_), do: nil

  defp has_nested_parts?(%{"parts" => parts}) when is_list(parts) and parts != [], do: true
  defp has_nested_parts?(_), do: false

  defp decode_body(nil), do: nil

  defp decode_body(data) do
    # Gmail uses URL-safe Base64 encoding, may or may not have padding
    case Base.url_decode64(data, padding: false) do
      {:ok, decoded} -> String.trim(decoded)
      :error -> nil
    end
  end

  defp strip_html(nil), do: nil

  defp strip_html(html) when is_binary(html) do
    html
    |> Floki.parse_document!()
    |> Floki.text(sep: " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  @doc """
  Extracts message IDs from messagesAdded entries in the Gmail history list.
  Only returns IDs from messages that were newly added.

  - Note: the "historyId" => _ case is to handle a case where there are
  no new message to process, and only the historyId is returned.
  """
  @spec get_latest_message_ids(map()) :: [String.t()]
  def get_latest_message_ids(%{"history" => history}) do
    history
    |> Enum.filter(&Map.has_key?(&1, "messagesAdded"))
    |> Enum.flat_map(fn entry ->
      entry["messagesAdded"]
      |> Enum.map(& &1["message"]["id"])
    end)
  end

  def get_latest_message_ids(%{"historyId" => _}) do
    []
  end

  @doc """
  Format a message from Google into a map with most of the important information.
  More information comes later in the flow, like "direction" and "contact_id".
  """
  @spec format_message(map()) :: map()
  def format_message(message) do
    headers = message["payload"]["headers"]

    %{
      subject: get_header(headers, "Subject"),
      from: extract_email_addresses(headers, :from),
      to: extract_email_addresses(headers, :to),
      date: get_header(headers, "date"),
      id: message["id"],
      thread_id: message["threadId"]
    }
  end

  @spec categorize_messages([map()], String.t()) :: [map()]
  def categorize_messages(messages, user_email) do
    messages
    |> expand_multiple_recipients()
    |> Enum.map(fn message ->
      cond do
        # If the message is from the user, it's sent
        message.from == user_email ->
          Map.put(message, :direction, "sent")

        # If the user's email is in the to field (now always a single email)
        message.to == user_email ->
          Map.put(message, :direction, "received")

        # If we can't categorize it, we'll skip it
        true ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  In cases where an email was sent to multiple recipients, we need to expand it into multiple messages
  so that a ContactInteraction can be created for each recipient.
  """
  @spec expand_multiple_recipients([map()]) :: [map()]
  def expand_multiple_recipients(messages) do
    messages
    |> Enum.flat_map(&expand_recipients_for_message/1)
    |> Enum.reject(&is_nil(&1))
  end

  defp expand_recipients_for_message(%{to: to_list} = message) when is_list(to_list) do
    Enum.map(to_list, fn recipient -> %{message | to: recipient} end)
  end

  defp expand_recipients_for_message(message), do: [message]

  @doc """
  Sends an email using the Gmail API.
  """
  @spec send_email(ExternalAccount.t(), map()) :: {:ok, map()} | {:error, any()}
  def send_email(ea, attrs) do
    # Create RFC2822 formatted email that Google requires.
    email_content =
      [
        "From: #{attrs.from}",
        "To: #{attrs.to}",
        "Subject: #{attrs.subject}",
        "MIME-Version: 1.0",
        "Content-Type: text/html; charset=UTF-8",
        # Empty line separating headers from body
        "",
        attrs.body
      ]
      |> Enum.join("\r\n")

    # Base64 URL encode the email content
    encoded_email = Base.url_encode64(email_content)

    payload = %{
      "raw" => encoded_email
    }

    with {:ok, token} <- Auth.get_latest_token(ea) do
      token
      |> client()
      |> Tesla.post("/users/#{ea.provider_user_id}/messages/send", payload)
      |> handle_response()
    end
  end

  defp find_insensitive(header, name) do
    header
    |> Map.get("name", "")
    |> then(&Regex.match?(~r/^#{name}$/i, &1))
  end

  defp get_header(nil, _name), do: nil
  defp get_header([], _name), do: nil

  defp get_header(headers, name) do
    case Enum.find(headers, &find_insensitive(&1, name)) do
      nil -> nil
      header -> Map.get(header, "value")
    end
  end

  defp extract_email_addresses(nil, _type), do: []
  defp extract_email_addresses([], _type), do: []

  defp extract_email_addresses(headers, :to) do
    headers
    |> get_header("To")
    |> extract_email()
  end

  defp extract_email_addresses(headers, :from) do
    headers
    |> get_header("From")
    |> extract_email()
    |> List.first()
  end

  # Extracts a single email address from a string, which appears to look like this:
  # "John Doe <john.doe@example.com>"
  defp extract_email(nil), do: nil

  defp extract_email(address) do
    Regex.scan(~r/([a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+\.[a-zA-Z0-9_-]+)/i, address, capture: :first)
    |> List.flatten()
  end

  defp handle_response({:ok, %{status: code, body: body}}) when code in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %{status: code} = response}) when code == 404 do
    Logger.warning("Requested entity not found.", details: inspect(response))

    {:error, "Requested entity not found."}
  end

  defp handle_response({:ok, %{status: code}}) when code == 401 do
    Logger.warning("Unauthorized request to Google.")

    {:error, "Unauthorized request to Google."}
  end

  defp handle_response({:ok, %{status: 400} = response}) do
    Logger.warning("Invalid Argument in request to Google", details: inspect(response))

    {:error, response}
  end

  defp handle_response({:ok, response}) do
    Logger.warning("Unexpected Response from Google", details: inspect(response))

    {:ok, response}
  end

  defp handle_response({:error, response}) do
    Logger.warning("Unexpected Error Response from Google", details: inspect(response))

    {:error, response}
  end

  defp config do
    Application.get_env(:walt_ui, __MODULE__)
  end

  defp client(access_token) do
    middleware = [
      {Tesla.Middleware.BaseUrl, config()[:base_url]},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.BearerAuth, token: access_token},
      {Tesla.Middleware.Retry,
       delay: 1000,
       max_retries: 5,
       max_delay: 30_000,
       should_retry: fn
         {:ok, %{status: 429}} -> true
         {:ok, %{status: status}} when status >= 500 -> true
         {:error, _} -> true
         _ -> false
       end}
    ]

    adapter = Application.get_env(:tesla, :adapter, Tesla.Adapter.Hackney)

    Tesla.client(middleware, adapter)
  end

  def filter_messages_with_contacts(messages, ea) do
    # Extract all unique contact emails from messages
    unique_emails =
      messages
      |> Enum.map(fn message ->
        if message.from == ea.email, do: message.to, else: message.from
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # Single bulk lookup for all emails
    contact_map = Contacts.get_contacts_by_emails(ea.user_id, unique_emails)

    # Filter and annotate messages using the contact map
    Enum.reduce(messages, [], fn message, acc ->
      contact_email = if message.from == ea.email, do: message.to, else: message.from

      case Map.get(contact_map, contact_email, []) do
        # No contacts found with this email
        [] -> acc
        contact_ids -> [Map.put(message, :contact_ids, contact_ids) | acc]
      end
    end)
    # Preserve original message order
    |> Enum.reverse()
  end

  def format_date(message) do
    date_string = Map.get(message, :date)

    case parse_gmail_date(date_string) do
      {:ok, parsed_date} ->
        Map.merge(message, %{meeting_time: parsed_date})

      {:error, _reason} ->
        Logger.warning("Failed to parse Gmail date, skipping message",
          date_string: date_string,
          message_id: message.id
        )

        # Return nil to indicate parsing failure
        nil
    end
  end

  # Helper function to handle multiple Gmail date formats
  defp parse_gmail_date(nil), do: {:error, :nil_date}
  defp parse_gmail_date(""), do: {:error, :empty_date}

  defp parse_gmail_date(date_string) do
    # Common Gmail date formats to try
    formats = [
      # Standard RFC2822
      "{WDshort}, {D} {Mshort} {YYYY} {h24}:{m}:{s} {Z}",
      # Timezone abbreviation
      "{WDshort}, {D} {Mshort} {YYYY} {h24}:{m}:{s} {Zabbr}",
      # No weekday
      "{D} {Mshort} {YYYY} {h24}:{m}:{s} {Z}",
      # ISO-ish format
      "{YYYY}-{M}-{D} {h24}:{m}:{s}",
      # No timezone
      "{D} {Mshort} {YYYY} {h24}:{m}:{s}"
    ]

    try_parse_formats(date_string, formats)
  end

  defp try_parse_formats(date_string, [format | remaining_formats]) do
    case Timex.parse(date_string, format) do
      {:ok, parsed_date} ->
        {:ok,
         parsed_date
         |> DateTime.shift_zone!("Etc/UTC")
         |> DateTime.to_naive()}

      {:error, _} ->
        try_parse_formats(date_string, remaining_formats)
    end
  end

  defp try_parse_formats(date_string, []) do
    {:error, {:unparseable_date, date_string}}
  end

  defp add_message_link(message) do
    Map.put(message, :message_link, "https://mail.google.com/mail/u/#all/#{message.id}")
  end

  # Helper function to fetch and format messages
  defp fetch_and_format_messages(ea, message_ids) do
    Logger.info("Attempting to sync #{length(message_ids)}", email: ea.email)

    message_ids
    |> Enum.map(&get_message(ea, &1))
    |> Enum.flat_map(fn
      {:ok, body} ->
        [body]

      {:error, error} ->
        Logger.warning("Failed to fetch message",
          error: inspect(error),
          external_account_id: ea.id
        )

        []
    end)
    |> Enum.map(&format_message/1)
  end

  defp update_gmail_history(ea) do
    Logger.info("Updating ExternalAccount Gmail History ID", email: ea.email)

    ea
    |> get_profile()
    |> case do
      {:ok, %{"historyId" => history_id}} ->
        ExternalAccounts.update(ea, %{gmail_history_id: history_id})

      {:error, error} ->
        Logger.error("Failed to update Gmail history", error: inspect(error))
        {:error, error}
    end
  end
end
