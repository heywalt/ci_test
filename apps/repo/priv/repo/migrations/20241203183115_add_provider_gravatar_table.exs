defmodule Repo.Migrations.AddProviderGravatarTable do
  use Ecto.Migration

  def change do
    create table(:provider_gravatar, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :email, :string

      add :unified_contact_id,
          references(:unified_contacts, type: :binary_id, on_delete: :delete_all)

      add :url, :text

      timestamps()
    end

    create index(:provider_gravatar, [:unified_contact_id])
  end
end
