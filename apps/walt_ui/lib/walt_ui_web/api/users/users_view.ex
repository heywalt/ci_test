defmodule WaltUiWeb.Api.UsersView do
  use JSONAPI.View, type: "users"

  alias WaltUi.Google.Gcs

  def fields do
    [
      :auth_uid,
      :avatar,
      :bio,
      :company_name,
      :email,
      :external_accounts,
      :first_name,
      :id,
      :last_name,
      :phone,
      :type
    ]
  end

  # def meta(data, _conn) do
  #   # this will add meta to each record
  #   # To add meta as a top level property, pass as argument to render function (shown below)
  #   %{meta_text: "meta_#{data[:text]}"}
  # end

  def avatar(%{avatar: avatar}, _conn) do
    Gcs.file_delivery_url(avatar)
  end

  def external_accounts(%{external_accounts: []}), do: []

  def external_accounts(%{external_accounts: _eas}) do
    [external_accounts: WaltUiWeb.Api.ExternalAccountsView]
  end

  def relationships do
    [contacts: WaltUiWeb.Api.ContactsView]
  end
end
