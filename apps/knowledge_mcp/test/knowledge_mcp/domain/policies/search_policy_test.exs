defmodule KnowledgeMcp.Domain.Policies.SearchPolicyTest do
  use ExUnit.Case, async: true

  alias KnowledgeMcp.Domain.Policies.SearchPolicy
  alias KnowledgeMcp.Domain.Entities.KnowledgeEntry

  describe "validate_search_params/1" do
    test "returns :ok when query is present" do
      assert {:ok, params} = SearchPolicy.validate_search_params(%{query: "elixir"})
      assert params.query == "elixir"
    end

    test "returns :ok when tags are present" do
      assert {:ok, params} = SearchPolicy.validate_search_params(%{tags: ["elixir"]})
      assert params.tags == ["elixir"]
    end

    test "returns :ok when category is present" do
      assert {:ok, params} = SearchPolicy.validate_search_params(%{category: "how_to"})
      assert params.category == "how_to"
    end

    test "returns {:error, :empty_search} when none provided" do
      assert {:error, :empty_search} = SearchPolicy.validate_search_params(%{})
    end

    test "returns {:error, :empty_search} when all nil" do
      assert {:error, :empty_search} =
               SearchPolicy.validate_search_params(%{query: nil, tags: nil, category: nil})
    end

    test "returns {:error, :empty_search} when query is empty string" do
      assert {:error, :empty_search} =
               SearchPolicy.validate_search_params(%{query: "", tags: [], category: nil})
    end

    test "clamps limit to default 20 when not provided" do
      assert {:ok, params} = SearchPolicy.validate_search_params(%{query: "test"})
      assert params.limit == 20
    end

    test "clamps limit to 1 when below range" do
      assert {:ok, params} = SearchPolicy.validate_search_params(%{query: "test", limit: 0})
      assert params.limit == 1
    end

    test "clamps limit to 100 when above range" do
      assert {:ok, params} = SearchPolicy.validate_search_params(%{query: "test", limit: 200})
      assert params.limit == 100
    end

    test "returns {:error, :invalid_category} for bad category filter" do
      assert {:error, :invalid_category} =
               SearchPolicy.validate_search_params(%{category: "invalid_category"})
    end
  end

  describe "score_relevance/2" do
    test "returns higher score for title match than body match" do
      entry =
        KnowledgeEntry.new(%{title: "Elixir patterns", body: "Some content about other things"})

      title_score = SearchPolicy.score_relevance(entry, "elixir")

      entry_body =
        KnowledgeEntry.new(%{title: "Other title", body: "Some content about elixir things"})

      body_score = SearchPolicy.score_relevance(entry_body, "elixir")

      assert title_score > body_score
    end

    test "returns 0 for no match" do
      entry = KnowledgeEntry.new(%{title: "About cats", body: "Cats are great"})
      assert SearchPolicy.score_relevance(entry, "elixir") == 0
    end

    test "is case-insensitive" do
      entry = KnowledgeEntry.new(%{title: "ELIXIR Patterns", body: "content"})
      score1 = SearchPolicy.score_relevance(entry, "elixir")
      score2 = SearchPolicy.score_relevance(entry, "ELIXIR")
      assert score1 > 0
      assert score1 == score2
    end
  end

  describe "matches_tags?/2" do
    test "returns true when entry has ALL specified tags (AND logic)" do
      entry = KnowledgeEntry.new(%{tags: ["elixir", "testing", "tdd"]})
      assert SearchPolicy.matches_tags?(entry, ["elixir", "testing"])
    end

    test "returns false when entry is missing any specified tag" do
      entry = KnowledgeEntry.new(%{tags: ["elixir"]})
      refute SearchPolicy.matches_tags?(entry, ["elixir", "testing"])
    end

    test "returns true when no filter tags specified" do
      entry = KnowledgeEntry.new(%{tags: ["anything"]})
      assert SearchPolicy.matches_tags?(entry, [])
    end

    test "returns true when filter tags is nil" do
      entry = KnowledgeEntry.new(%{tags: ["anything"]})
      assert SearchPolicy.matches_tags?(entry, nil)
    end
  end

  describe "matches_category?/2" do
    test "returns true when entry matches category filter" do
      entry = KnowledgeEntry.new(%{category: "how_to"})
      assert SearchPolicy.matches_category?(entry, "how_to")
    end

    test "returns false when entry does not match category filter" do
      entry = KnowledgeEntry.new(%{category: "concept"})
      refute SearchPolicy.matches_category?(entry, "how_to")
    end

    test "returns true when no category filter (nil)" do
      entry = KnowledgeEntry.new(%{category: "anything"})
      assert SearchPolicy.matches_category?(entry, nil)
    end
  end

  describe "clamp_depth/1" do
    test "returns default 2 when nil" do
      assert SearchPolicy.clamp_depth(nil) == 2
    end

    test "clamps to 1 when below range" do
      assert SearchPolicy.clamp_depth(0) == 1
      assert SearchPolicy.clamp_depth(-1) == 1
    end

    test "clamps to 5 when above range" do
      assert SearchPolicy.clamp_depth(10) == 5
      assert SearchPolicy.clamp_depth(100) == 5
    end

    test "returns value within range unchanged" do
      assert SearchPolicy.clamp_depth(1) == 1
      assert SearchPolicy.clamp_depth(3) == 3
      assert SearchPolicy.clamp_depth(5) == 5
    end
  end
end
