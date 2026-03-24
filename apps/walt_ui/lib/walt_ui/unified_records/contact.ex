defmodule WaltUi.UnifiedRecords.Contact do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @required ~w(phone)a
  @optional ~w(faraday_mismatch)a

  @derive {Jason.Encoder, only: [:endato, :faraday, :gravatar, :id, :phone]}
  schema "unified_contacts" do
    field :phone, TenDigitPhone
    field :faraday_mismatch, :string

    has_one :endato, WaltUi.Providers.Endato, foreign_key: :unified_contact_id
    has_one :faraday, WaltUi.Providers.Faraday, foreign_key: :unified_contact_id
    has_one :gravatar, WaltUi.Providers.Gravatar, foreign_key: :unified_contact_id
    has_one :jitter, WaltUi.Providers.Jitter, foreign_key: :unified_contact_id

    has_many :contacts, WaltUi.Projections.Contact, foreign_key: :unified_contact_id

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(record \\ %__MODULE__{}, attrs) do
    record
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:phone)
  end
end
