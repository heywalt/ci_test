defmodule Repo.Migrations.FixProviderFaradayColumnTypes do
  use Ecto.Migration

  def change do
    alter table(:provider_faraday) do
      remove :affluency, :string
      remove :interest_in_grandchildren, :string
      remove :latest_mortgage_interest_rate, :string

      add :affluency, :boolean
      add :interest_in_grandchildren, :boolean
      add :latest_mortgage_interest_rate, :float
    end
  end
end
