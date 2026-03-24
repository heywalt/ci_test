defmodule WaltUi.Providers.Endato do
  @moduledoc false

  use Repo.WaltSchema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields ~w(age city email first_name last_name
             middle_name phone state street_1
             street_2 unified_contact_id zip)a

  @derive {Jason.Encoder, only: @fields}
  schema "provider_endato" do
    field :age, :integer
    field :city, :string
    field :email, :string
    field :first_name, :string
    field :last_name, :string
    field :middle_name, :string
    field :phone, TenDigitPhone
    field :state, :string
    field :street_1, :string
    field :street_2, :string
    field :zip, :string

    belongs_to :unified_contact, WaltUi.UnifiedRecords.Contact

    timestamps()
  end

  @spec changeset(t, map) :: Ecto.Changeset.t()
  def changeset(record \\ %__MODULE__{}, attrs) do
    cast(record, attrs, @fields)
  end
end
