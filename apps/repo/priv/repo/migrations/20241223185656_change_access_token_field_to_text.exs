defmodule Repo.Migrations.ChangeAccessTokenFieldToText do
  use Ecto.Migration

  def change do
    alter table(:external_accounts) do
      modify :access_token, :text, from: :string
    end
  end
end
