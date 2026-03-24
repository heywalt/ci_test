defmodule WaltUi.MCP.Tools.GetContactTimeline do
  @moduledoc """
  Get the interaction timeline for a contact including meetings, emails, and creation date.
  Returns chronologically ordered interactions with details.
  """

  use Anubis.Server.Component, type: :tool

  require Logger

  alias WaltUi.ContactInteractions
  alias WaltUi.Projections.Contact

  @valid_activity_types ~w(contact_created contact_invited contact_corresponded)

  schema do
    field :contact_id, :string, required: true, description: "UUID of the contact"

    field :activity_type, :string,
      description:
        "Optional filter: 'contact_invited' (meetings), 'contact_corresponded' (emails), or 'contact_created'"

    field :limit, :integer, default: 20, description: "Maximum results to return"
  end

  @impl true
  def execute(params, frame) do
    user_id = frame.assigns[:user_id]
    contact_id = Map.get(params, "contact_id")
    activity_type = Map.get(params, "activity_type")
    limit = Map.get(params, "limit", 20)

    Logger.info("GetContactTimeline called for contact: #{contact_id}")

    with :ok <- validate_user_id(user_id),
         :ok <- validate_contact_ownership(contact_id, user_id),
         :ok <- validate_activity_type(activity_type) do
      interactions =
        contact_id
        |> ContactInteractions.for_contact()
        |> filter_by_activity_type(activity_type)
        |> Enum.take(limit)
        |> format_interactions()

      Logger.info("GetContactTimeline found #{length(interactions)} interactions")
      {:ok, %{"timeline" => interactions}}
    end
  end

  defp validate_user_id(nil), do: {:error, "user_id is required in context"}
  defp validate_user_id(_user_id), do: :ok

  defp validate_contact_ownership(contact_id, user_id) do
    case Repo.get_by(Contact, id: contact_id, user_id: user_id) do
      nil -> {:error, "Contact not found or not authorized"}
      _contact -> :ok
    end
  end

  defp validate_activity_type(nil), do: :ok

  defp validate_activity_type(activity_type) when activity_type in @valid_activity_types, do: :ok

  defp validate_activity_type(activity_type) do
    {:error,
     "Invalid activity_type: #{activity_type}. Must be one of: #{Enum.join(@valid_activity_types, ", ")}"}
  end

  defp filter_by_activity_type(interactions, nil), do: interactions

  defp filter_by_activity_type(interactions, activity_type) do
    type_atom = String.to_existing_atom(activity_type)
    Enum.filter(interactions, &(&1.activity_type == type_atom))
  end

  defp format_interactions(interactions) do
    Enum.map(interactions, &format_interaction/1)
  end

  defp format_interaction(%{activity_type: :contact_created} = interaction) do
    %{
      "type" => "contact_created",
      "description" => "Contact created",
      "occurred_at" => format_datetime(interaction.occurred_at)
    }
  end

  defp format_interaction(%{activity_type: :contact_invited, metadata: metadata} = interaction) do
    %{
      "type" => "meeting",
      "description" => format_meeting_description(metadata),
      "occurred_at" => format_datetime(interaction.occurred_at),
      "meeting_name" => get_in(metadata, ["name"]),
      "start_time" => get_in(metadata, ["start_time"]),
      "end_time" => get_in(metadata, ["end_time"]),
      "location" => get_in(metadata, ["location"]),
      "link" => get_in(metadata, ["link"]),
      "status" => get_in(metadata, ["status"])
    }
  end

  defp format_interaction(
         %{activity_type: :contact_corresponded, metadata: metadata} = interaction
       ) do
    direction = get_in(metadata, ["direction"])

    %{
      "type" => "email",
      "description" => format_email_description(direction, metadata),
      "occurred_at" => format_datetime(interaction.occurred_at),
      "direction" => direction,
      "subject" => get_in(metadata, ["subject"]),
      "from" => get_in(metadata, ["from"]),
      "to" => get_in(metadata, ["to"]),
      "message_link" => get_in(metadata, ["message_link"])
    }
  end

  defp format_meeting_description(metadata) do
    name = get_in(metadata, ["name"]) || "Untitled meeting"
    "Meeting: #{name}"
  end

  defp format_email_description(direction, metadata) do
    subject = get_in(metadata, ["subject"]) || "(no subject)"
    direction_text = if direction == "inbound", do: "received", else: "sent"
    "Email #{direction_text}: #{subject}"
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(%NaiveDateTime{} = dt) do
    NaiveDateTime.to_iso8601(dt)
  end

  defp format_datetime(dt), do: to_string(dt)
end
