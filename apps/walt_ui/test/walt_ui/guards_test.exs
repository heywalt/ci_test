defmodule WaltUi.GuardsTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory
  import WaltUi.Guards

  describe "is_premium_user/1" do
    test "returns true for :premium tier user" do
      user = insert(:user, tier: :premium)
      assert is_premium_user(user)
    end

    test "returns false for :freemium tier user" do
      user = insert(:user, tier: :freemium)
      refute is_premium_user(user)
    end
  end
end
