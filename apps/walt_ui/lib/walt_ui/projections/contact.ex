defmodule WaltUi.Projections.Contact do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  alias WaltUi.Projections.Contact.Email
  alias WaltUi.Projections.Contact.PhoneNumber

  @type t :: %__MODULE__{}

  @required ~w(id phone user_id)a
  @optional ~w(anniversary avatar birthday city date_of_home_purchase email enrichment_id first_name is_favorite is_hidden last_name
               latitude longitude ptt remote_id remote_source standard_phone state street_1 street_2 unified_contact_id zip)a

  @derive Jason.Encoder
  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "projection_contacts" do
    field :anniversary, :date
    field :avatar, :string
    field :birthday, :date
    field :city, :string
    field :date_of_home_purchase, :date
    field :email, :string
    field :enrichment_id, :binary_id
    field :enrichment, :map, virtual: true
    field :first_name, :string
    field :is_favorite, :boolean
    field :is_hidden, :boolean, default: false
    field :is_showcased, :boolean, virtual: true
    field :last_name, :string
    field :latitude, :decimal
    field :longitude, :decimal
    field :phone, :string
    field :ptt, :integer
    field :remote_id, :string
    field :remote_source, :string
    field :standard_phone, Repo.Types.TenDigitPhone
    field :state, :string
    field :street_1, :string
    field :street_2, :string
    field :user_id, :binary_id
    field :zip, :string

    belongs_to :unified_contact, WaltUi.UnifiedRecords.Contact

    has_many :events, WaltUi.Contacts.ContactEvent
    has_many :notes, WaltUi.Directory.Note
    many_to_many :tags, WaltUi.Tags.Tag, join_through: "contact_tags"

    embeds_many :phone_numbers, PhoneNumber, on_replace: :delete
    embeds_many :emails, Email, on_replace: :delete

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(contact \\ %__MODULE__{}, attrs) do
    contact
    |> Map.put_new_lazy(:id, &Ecto.UUID.generate/0)
    |> cast(attrs, @required ++ @optional)
    |> cast_embed(:phone_numbers, with: &PhoneNumber.changeset/2)
    |> cast_embed(:emails, with: &Email.changeset/2)
    |> validate_required(@required)
    |> validate_length(:email, max: 254)
    |> validate_phone()
    |> unique_constraint([:user_id, :remote_id, :remote_source])
  end

  @bogus_phone_codes ["800", "833", "844", "855", "866", "877", "888", "900"]

  def validate_phone(changeset) do
    validate_change(changeset, :phone, fn :phone, phone ->
      trimmed =
        phone
        |> to_string()
        |> String.replace("+1", "")
        |> String.trim()

      if String.starts_with?(trimmed, @bogus_phone_codes) do
        [phone: "contains a commercial area code"]
      else
        []
      end
    end)
  end
end
