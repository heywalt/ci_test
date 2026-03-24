defmodule Repo.Migrations.AddProviderJitterTable do
  use Ecto.Migration

  def change do
    create table(:provider_jitter, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :ptt, :integer

      add :unified_contact_id,
          references(:unified_contacts, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:provider_jitter, [:unified_contact_id], unique: true)
  end
end
