defmodule WaltUi.Handlers.AutoTagReaOnLeadCreated do
  @moduledoc """
  Event handler that automatically tags and hides contacts detected as real
  estate agents when a new lead is created. Matching is based on email
  patterns associated with known brokerages and real-estate keywords, as well
  as whether the contact's email matches an existing system user or external
  account.
  """

  use Commanded.Event.Handler,
    application: CQRS,
    name: __MODULE__,
    start_from: :current

  require Logger

  alias CQRS.Leads.Events.LeadCreated
  alias WaltUi.Contacts.RealEstateAgentEmailMatcher
  alias WaltUi.ContactTags
  alias WaltUi.Tags

  @tag_name "Real Estate Agent"
  @tag_color "red"

  def handle(%LeadCreated{} = event, _metadata) do
    emails = extract_emails(event)

    if likely_rea?(emails) do
      tag_and_hide(event.user_id, event.id)
    else
      :ok
    end
  end

  defp likely_rea?(emails) do
    RealEstateAgentEmailMatcher.any_match?(emails) or
      RealEstateAgentEmailMatcher.any_system_user_match?(emails)
  end

  defp extract_emails(event) do
    embedded =
      (event.emails || [])
      |> Enum.map(fn
        %{"email" => email} -> email
        %{email: email} -> email
        _ -> nil
      end)

    [event.email | embedded]
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp tag_and_hide(user_id, contact_id) do
    with {:ok, tag} <- Tags.find_or_create_tag(user_id, @tag_name, @tag_color),
         {:ok, _contact_tag} <- ContactTags.find_or_create(user_id, contact_id, tag.id),
         {:ok, _aggregate} <-
           CQRS.update_contact(%{id: contact_id, user_id: user_id}, %{is_hidden: true}) do
      Logger.info("Auto-tagged and hid REA contact",
        contact_id: contact_id,
        user_id: user_id
      )

      :ok
    else
      {:error, reason} ->
        Logger.warning("Failed to auto-tag/hide REA contact",
          contact_id: contact_id,
          user_id: user_id,
          error: inspect(reason)
        )

        :ok
    end
  end
end
