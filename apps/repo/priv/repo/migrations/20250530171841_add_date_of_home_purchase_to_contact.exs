defmodule Repo.Migrations.AddDateOfHomePurchaseToContact do
  use Ecto.Migration

  def change do
    alter table(:projection_contacts) do
      add :date_of_home_purchase, :date
    end
  end
end
