defmodule WaltUi.Contacts.Highlight do
  @moduledoc false

  use Repo.WaltSchema

  @type t :: %__MODULE__{}

  schema "contact_highlights" do
    belongs_to :contact, WaltUi.Projections.Contact
    belongs_to :user, WaltUi.Account.User

    timestamps()
  end
end
