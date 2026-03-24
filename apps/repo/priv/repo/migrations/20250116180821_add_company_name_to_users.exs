defmodule Repo.Migrations.AddCompanyNameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :company_name, :string
    end
  end
end
