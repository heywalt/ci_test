defmodule WaltUi.Contacts.RealEstateAgentEmailMatcherTest do
  use Repo.DataCase, async: true

  import WaltUi.Factory

  alias WaltUi.Contacts.RealEstateAgentEmailMatcher

  describe "match?/1" do
    test "returns true for matching email" do
      assert RealEstateAgentEmailMatcher.match?("jane@kw.com")
    end

    test "returns false for non-matching email" do
      refute RealEstateAgentEmailMatcher.match?("jane@gmail.com")
    end

    test "returns false for nil" do
      refute RealEstateAgentEmailMatcher.match?(nil)
    end
  end

  describe "any_match?/1" do
    test "matches exact domain @kw.com" do
      assert RealEstateAgentEmailMatcher.any_match?(["jane@kw.com"])
    end

    test "matches exact domain @exprealty.com" do
      assert RealEstateAgentEmailMatcher.any_match?(["agent@exprealty.com"])
    end

    test "matches exact domain @hhgus.com" do
      assert RealEstateAgentEmailMatcher.any_match?(["john@hhgus.com"])
    end

    test "matches partial domain @bhhs" do
      assert RealEstateAgentEmailMatcher.any_match?(["jane@bhhsrealty.com"])
    end

    test "matches partial domain @cb" do
      assert RealEstateAgentEmailMatcher.any_match?(["jane@cbrealty.com"])
    end

    test "matches substring 'realty' in email" do
      assert RealEstateAgentEmailMatcher.any_match?(["info@bigrealty.com"])
    end

    test "matches substring 'realtor' in local part" do
      assert RealEstateAgentEmailMatcher.any_match?(["realtor123@gmail.com"])
    end

    test "matches substring 'realestate' in email" do
      assert RealEstateAgentEmailMatcher.any_match?(["info@realestate.co"])
    end

    test "matches substring 'agent' in email" do
      assert RealEstateAgentEmailMatcher.any_match?(["topagent@gmail.com"])
    end

    test "matches substring 'home' in email" do
      assert RealEstateAgentEmailMatcher.any_match?(["salsellshomes@gmail.com"])
    end

    test "matches substring 'sell' in email" do
      assert RealEstateAgentEmailMatcher.any_match?(["salsellshomes@gmail.com"])
    end

    test "matches substring 'onegroup' in email" do
      assert RealEstateAgentEmailMatcher.any_match?(["info@onegroup.com"])
    end

    test "matches substring 'house' in email" do
      assert RealEstateAgentEmailMatcher.any_match?(["myhouse@example.com"])
    end

    test "matches case-insensitively" do
      assert RealEstateAgentEmailMatcher.any_match?(["Jane@KW.COM"])
    end

    test "returns true when any email in the list matches" do
      assert RealEstateAgentEmailMatcher.any_match?(["jane@gmail.com", "jane@kw.com"])
    end

    test "does not match generic email" do
      refute RealEstateAgentEmailMatcher.any_match?(["jane@gmail.com"])
    end

    test "does not match unrelated email" do
      refute RealEstateAgentEmailMatcher.any_match?(["john@yahoo.com"])
    end

    test "returns false for empty list" do
      refute RealEstateAgentEmailMatcher.any_match?([])
    end

    test "returns false for nil" do
      refute RealEstateAgentEmailMatcher.any_match?(nil)
    end
  end

  describe "any_system_user_match?/1" do
    test "returns true when email matches a user's email" do
      insert(:user, email: "jane@gmail.com")

      assert RealEstateAgentEmailMatcher.any_system_user_match?(["jane@gmail.com"])
    end

    test "returns true when email matches a user's email case-insensitively" do
      insert(:user, email: "Jane@Gmail.com")

      assert RealEstateAgentEmailMatcher.any_system_user_match?(["jane@gmail.com"])
    end

    test "returns true when email matches an external_account's email" do
      insert(:external_account, email: "jane@gmail.com")

      assert RealEstateAgentEmailMatcher.any_system_user_match?(["jane@gmail.com"])
    end

    test "returns true when email matches an external_account's email case-insensitively" do
      insert(:external_account, email: "Jane@Gmail.com")

      assert RealEstateAgentEmailMatcher.any_system_user_match?(["jane@gmail.com"])
    end

    test "returns true when any email in the list matches" do
      insert(:user, email: "bob@yahoo.com")

      assert RealEstateAgentEmailMatcher.any_system_user_match?([
               "jane@gmail.com",
               "bob@yahoo.com"
             ])
    end

    test "returns false when no emails match any user or external account" do
      refute RealEstateAgentEmailMatcher.any_system_user_match?(["nobody@nowhere.com"])
    end

    test "returns false for empty list" do
      refute RealEstateAgentEmailMatcher.any_system_user_match?([])
    end

    test "returns false for nil" do
      refute RealEstateAgentEmailMatcher.any_system_user_match?(nil)
    end
  end
end
