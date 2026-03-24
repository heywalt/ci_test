defmodule Repo.Migrations.AddNewFaradayFields do
  use Ecto.Migration

  def change do
    alter table(:contact_metadata) do
      add :is_twitter_user, :boolean
      add :is_facebook_user, :boolean
      add :is_instagram_user, :boolean
      add :is_active_on_social_media, :boolean
      add :lot_size_in_acres, :string
      add :probability_to_have_hot_tub, :string
      add :home_equity_loan_date, :string
      add :home_equity_loan_amount, :string
      add :target_home_market_value, :string
    end
  end
end
