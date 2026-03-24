defmodule WaltUiWeb.Api.ExternalAccountsView do
  use JSONAPI.View, type: "external_accounts"

  def fields do
    [:id, :inserted_at, :provider, :updated_at, :user_id]
  end
end
