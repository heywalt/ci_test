defmodule WaltUi.Contacts.ContactEvent do
  @moduledoc """
  The ContactEvent schema.
  """
  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @optional [
    :note_id
  ]

  @required [:contact_id, :event, :type]

  @buying_events ~w(called met signed_agreement toured_home made_offer offer_accepted offer_rejected closed paused agreement_expired)

  @selling_events ~w(called met signed_agreement listed_property offer_receieved offer_accepted closed paused agreement_expired)

  @types ~w(buying selling)

  @derive {Jason.Encoder, except: [:__meta__, :contact, :note]}
  schema "contact_events" do
    field :event, :string
    field :type, :string

    belongs_to :contact, WaltUi.Projections.Contact
    belongs_to :note, WaltUi.Directory.Note

    timestamps()
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, @optional ++ @required)
    |> validate_required(@required)
    |> validate_inclusion(:type, @types)
    |> validate_event()
  end

  def validate_event(%{changes: %{type: type}} = changeset) do
    list = get_event_list_for_type(type)

    validate_change(changeset, :event, fn :event, event ->
      if Enum.member?(list, event) do
        []
      else
        [event: "Not a valid event of this type"]
      end
    end)
  end

  def validate_event(changeset) do
    validate_change(changeset, :event, fn :event, _event ->
      []
    end)
  end

  defp get_event_list_for_type(type) do
    Map.get(%{"buying" => @buying_events, "selling" => @selling_events}, type)
  end
end
