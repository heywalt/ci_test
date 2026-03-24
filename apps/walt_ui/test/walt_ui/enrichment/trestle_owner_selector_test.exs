defmodule WaltUi.Enrichment.TrestleOwnerSelectorTest do
  use ExUnit.Case, async: true

  alias WaltUi.Enrichment.TrestleOwnerSelector

  describe "select_best_owner/2" do
    test "selects owner with exact name match over others" do
      exact_match_owner = %{"firstname" => "John", "lastname" => "Smith"}
      partial_match_owner = %{"firstname" => "John", "lastname" => "Doe"}
      no_match_owner = %{"firstname" => "Alice", "lastname" => "Brown"}

      owners = [no_match_owner, exact_match_owner, partial_match_owner]
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == exact_match_owner
    end

    test "selects owner with best partial match when no exact match" do
      first_name_match = %{"firstname" => "John", "lastname" => "Brown"}
      last_name_match = %{"firstname" => "Alice", "lastname" => "Smith"}
      no_match_owner = %{"firstname" => "Bob", "lastname" => "Jones"}

      owners = [no_match_owner, first_name_match, last_name_match]
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result in [first_name_match, last_name_match]
    end

    test "falls back to first owner when no good matches found" do
      poor_match_1 = %{"firstname" => "Alice", "lastname" => "Brown"}
      poor_match_2 = %{"firstname" => "Bob", "lastname" => "Jones"}

      owners = [poor_match_1, poor_match_2]
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == poor_match_1
    end

    test "falls back to first owner when name_hint is nil" do
      owner_1 = %{"firstname" => "John", "lastname" => "Smith"}
      owner_2 = %{"firstname" => "Alice", "lastname" => "Brown"}

      owners = [owner_1, owner_2]
      name_hint = nil

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == owner_1
    end

    test "falls back to first owner when name_hint is empty string" do
      owner_1 = %{"firstname" => "John", "lastname" => "Smith"}
      owner_2 = %{"firstname" => "Alice", "lastname" => "Brown"}

      owners = [owner_1, owner_2]
      name_hint = ""

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == owner_1
    end

    test "handles name_hint with extra whitespace" do
      exact_match_owner = %{"firstname" => "John", "lastname" => "Smith"}
      other_owner = %{"firstname" => "Alice", "lastname" => "Brown"}

      owners = [other_owner, exact_match_owner]
      name_hint = "  John Smith  "

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == exact_match_owner
    end

    test "returns nil when owners list is empty" do
      owners = []
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == nil
    end

    test "returns single owner when only one owner provided" do
      owner = %{"firstname" => "John", "lastname" => "Smith"}
      owners = [owner]
      name_hint = "Alice Brown"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == owner
    end

    test "handles nil owners list" do
      owners = nil
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == nil
    end
  end

  describe "score_owner_name_match/2" do
    test "returns 100 for exact first and last name match" do
      owner = %{"firstname" => "John", "lastname" => "Smith"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end

    test "ignores case differences in exact matches" do
      owner = %{"firstname" => "john", "lastname" => "SMITH"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end

    test "returns 75 for exact first name match with different last name" do
      owner = %{"firstname" => "John", "lastname" => "Doe"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 75
    end

    test "returns 75 for exact last name match with different first name" do
      owner = %{"firstname" => "Jane", "lastname" => "Smith"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 75
    end

    test "returns 50 for similar names using string distance" do
      owner = %{"firstname" => "Jon", "lastname" => "Smyth"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 50
    end

    test "returns 0 for completely different names" do
      owner = %{"firstname" => "Alice", "lastname" => "Brown"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 0
    end

    test "handles API format with firstname/lastname fields" do
      owner = %{"firstname" => "John", "lastname" => "Smith"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end

    test "handles dummy format with nested name object" do
      owner = %{"name" => %{"first" => "John", "last" => "Smith"}}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end

    test "handles missing name fields gracefully" do
      owner = %{"firstname" => nil, "lastname" => "Smith"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score >= 0
      assert score <= 100
    end

    test "handles nil owner gracefully" do
      owner = nil
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 0
    end

    test "handles nil name_hint gracefully" do
      owner = %{"firstname" => "John", "lastname" => "Smith"}
      name_hint = nil

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 0
    end

    test "handles empty name_hint" do
      owner = %{"firstname" => "John", "lastname" => "Smith"}
      name_hint = ""

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 0
    end

    test "handles owner with missing name fields" do
      owner = %{"email" => "test@example.com"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 0
    end

    test "handles owner with malformed name structure" do
      owner = %{"name" => "John Smith"}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score >= 0
      assert score <= 100
    end

    test "handles extra whitespace in name_hint" do
      owner = %{"firstname" => "John", "lastname" => "Smith"}
      name_hint = "  John Smith  "

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end

    test "handles extra whitespace in owner names" do
      owner = %{"firstname" => "  John  ", "lastname" => "  Smith  "}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end

    test "handles middle names in owner data" do
      owner = %{"name" => %{"first" => "John", "middle" => "Michael", "last" => "Smith"}}
      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end

    test "handles single name in name_hint" do
      owner = %{"firstname" => "John", "lastname" => "Smith"}
      name_hint = "John"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 75
    end

    # Alternate name exact match tests (85 points)
    test "returns 85 for exact match on alternate name" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Andy Sedlak", "Drew S"]
      }

      name_hint = "Andy Sedlak"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 85
    end

    test "returns 85 for exact match on alternate name with different case" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["andy sedlak"]
      }

      name_hint = "Andy Sedlak"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 85
    end

    test "returns 85 for exact match on second alternate name in array" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["A Sedlak", "Drew Sedlak", "Andy S"]
      }

      name_hint = "Drew Sedlak"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 85
    end

    test "prefers primary name exact match (100) over alternate exact match (85)" do
      owner = %{
        "firstname" => "John",
        "lastname" => "Smith",
        "alternate_names" => ["Johnny Smith"]
      }

      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end

    # Alternate name partial match tests (60 points)
    test "returns 60 for first name match on alternate name" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Andy Johnson"]
      }

      name_hint = "Andy Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 60
    end

    test "returns 60 for last name match on alternate name" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["John Johnson"]
      }

      name_hint = "Mike Johnson"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 60
    end

    test "returns 60 for single name hint matching alternate first name" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Andy Sedlak"]
      }

      name_hint = "Andy"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 60
    end

    test "returns 60 for single name hint matching alternate last name" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Smith",
        "alternate_names" => ["John Sedlak"]
      }

      name_hint = "Sedlak"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 60
    end

    test "prefers primary partial match (75) over alternate partial match (60)" do
      owner = %{
        "firstname" => "John",
        "lastname" => "Smith",
        "alternate_names" => ["Johnny Doe"]
      }

      name_hint = "John Doe"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 75
    end

    # Alternate name fuzzy match tests (50 points)
    test "returns 50 for fuzzy match on alternate name" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Andy Sedlack"]
      }

      name_hint = "Andi Sedleck"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 50
    end

    test "returns 50 for fuzzy match on alternate name with typos" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Andy Sedlek"]
      }

      name_hint = "Andi Sedlick"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 50
    end

    test "treats primary and alternate fuzzy matches equally at 50 points" do
      # Primary fuzzy match
      owner1 = %{
        "firstname" => "Jon",
        "lastname" => "Smyth",
        "alternate_names" => []
      }

      score1 = TrestleOwnerSelector.score_owner_name_match(owner1, "John Smith")

      # Alternate fuzzy match
      owner2 = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Jon Smyth"]
      }

      score2 = TrestleOwnerSelector.score_owner_name_match(owner2, "John Smith")

      assert score1 == 50
      assert score2 == 50
    end

    # Edge cases
    test "handles owner with nil alternate_names field" do
      owner = %{
        "firstname" => "John",
        "lastname" => "Smith",
        "alternate_names" => nil
      }

      name_hint = "Andy Sedlak"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 0
    end

    test "handles owner with empty alternate_names array" do
      owner = %{
        "firstname" => "John",
        "lastname" => "Smith",
        "alternate_names" => []
      }

      name_hint = "Andy Sedlak"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 0
    end

    test "handles alternate names with middle names/initials" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Andy A Sedlak", "Andrew Alan Sedlak"]
      }

      name_hint = "Andy Sedlak"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 85
    end

    test "handles alternate names with special characters" do
      owner = %{
        "firstname" => "Mary",
        "lastname" => "Smith",
        "alternate_names" => ["Mary-Jane Smith", "M.J. Smith"]
      }

      name_hint = "Mary-Jane Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 85
    end

    test "handles alternate names with only single name" do
      owner = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Andy", "Drew"]
      }

      name_hint = "Andy"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 60
    end

    test "handles malformed alternate name strings" do
      owner = %{
        "firstname" => "John",
        "lastname" => "Smith",
        "alternate_names" => ["", "   ", nil]
      }

      name_hint = "John Smith"

      score = TrestleOwnerSelector.score_owner_name_match(owner, name_hint)
      assert score == 100
    end
  end

  describe "select_best_owner/2 with alternate names" do
    test "selects owner with alternate name exact match over poor primary matches" do
      owner1 = %{
        "firstname" => "Bob",
        "lastname" => "Johnson",
        "alternate_names" => []
      }

      owner2 = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["John Smith"]
      }

      owner3 = %{
        "firstname" => "Mike",
        "lastname" => "Williams",
        "alternate_names" => []
      }

      owners = [owner1, owner2, owner3]
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == owner2
    end

    test "selects owner with alternate name partial match when no exact matches" do
      owner1 = %{
        "firstname" => "Bob",
        "lastname" => "Johnson",
        "alternate_names" => ["Robert Johnson"]
      }

      owner2 = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["John Doe"]
      }

      owner3 = %{
        "firstname" => "Mike",
        "lastname" => "Williams",
        "alternate_names" => []
      }

      owners = [owner1, owner2, owner3]
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == owner2
    end

    test "selects first owner when all scores below 50 including alternate names" do
      owner1 = %{
        "firstname" => "Bob",
        "lastname" => "Johnson",
        "alternate_names" => ["Robert J"]
      }

      owner2 = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["Andy S"]
      }

      owners = [owner1, owner2]
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == owner1
    end

    test "selects owner with highest combined score from primary and alternate names" do
      owner1 = %{
        "firstname" => "John",
        "lastname" => "Doe",
        "alternate_names" => ["Johnny Doe"]
      }

      owner2 = %{
        "firstname" => "Andrew",
        "lastname" => "Sedlak",
        "alternate_names" => ["John Smith"]
      }

      owner3 = %{
        "firstname" => "Bob",
        "lastname" => "Smith",
        "alternate_names" => []
      }

      owners = [owner1, owner2, owner3]
      name_hint = "John Smith"

      result = TrestleOwnerSelector.select_best_owner(owners, name_hint, "test-enrichment-id")
      assert result == owner2
    end
  end
end
