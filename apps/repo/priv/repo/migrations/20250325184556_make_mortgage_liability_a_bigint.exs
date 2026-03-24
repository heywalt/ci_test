defmodule Repo.Migrations.MakeMortgageLiabilityABigint do
  use Ecto.Migration

  def change do
    alter table(:provider_faraday) do
      modify :latest_mortgage_amount, :bigint, from: :integer
    end
  end
end
