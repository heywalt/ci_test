defmodule WaltUi.Contacts.ContactTest do
  use Repo.DataCase

  import WaltUi.Factory

  alias WaltUi.Projections.Contact

  describe "changeset/2" do
    test "800 phone numbers return an error changeset" do
      user = insert(:user)
      attrs = %{id: Ecto.UUID.generate(), phone: "800-555-1212", user_id: user.id}

      errors = Contact.changeset(%Contact{}, attrs).errors

      assert [phone: {"contains a commercial area code", []}] == errors
    end

    test "+1800 phone numbers return an error changeset" do
      user = insert(:user)
      attrs = %{id: Ecto.UUID.generate(), phone: "+1 800-555-1212", user_id: user.id}

      errors = Contact.changeset(%Contact{}, attrs).errors

      assert [phone: {"contains a commercial area code", []}] == errors
    end
  end
end
