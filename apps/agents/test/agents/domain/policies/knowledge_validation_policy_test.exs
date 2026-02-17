defmodule Agents.Domain.Policies.KnowledgeValidationPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Domain.Policies.KnowledgeValidationPolicy

  describe "valid_category?/1" do
    for category <- ~w(how_to pattern convention architecture_decision gotcha concept) do
      test "returns true for #{category}" do
        assert KnowledgeValidationPolicy.valid_category?(unquote(category))
      end
    end

    test "returns false for invalid categories" do
      refute KnowledgeValidationPolicy.valid_category?("invalid")
      refute KnowledgeValidationPolicy.valid_category?("")
      refute KnowledgeValidationPolicy.valid_category?(nil)
    end
  end

  describe "valid_relationship_type?/1" do
    for type <- ~w(relates_to depends_on prerequisite_for example_of part_of supersedes) do
      test "returns true for #{type}" do
        assert KnowledgeValidationPolicy.valid_relationship_type?(unquote(type))
      end
    end

    test "returns false for invalid types" do
      refute KnowledgeValidationPolicy.valid_relationship_type?("invalid")
      refute KnowledgeValidationPolicy.valid_relationship_type?("")
      refute KnowledgeValidationPolicy.valid_relationship_type?(nil)
    end
  end

  describe "validate_entry_attrs/1" do
    test "returns :ok for valid attrs" do
      attrs = %{title: "How to deploy", body: "Steps...", category: "how_to"}
      assert :ok = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end

    test "returns {:error, :title_required} when title missing" do
      attrs = %{body: "Content", category: "how_to"}
      assert {:error, :title_required} = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end

    test "returns {:error, :title_required} when title is empty string" do
      attrs = %{title: "", body: "Content", category: "how_to"}
      assert {:error, :title_required} = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end

    test "returns {:error, :body_required} when body missing" do
      attrs = %{title: "Title", category: "how_to"}
      assert {:error, :body_required} = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end

    test "returns {:error, :body_required} when body is empty string" do
      attrs = %{title: "Title", body: "", category: "how_to"}
      assert {:error, :body_required} = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end

    test "returns {:error, :invalid_category} for bad category" do
      attrs = %{title: "Title", body: "Content", category: "invalid"}
      assert {:error, :invalid_category} = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end

    test "returns {:error, :invalid_category} when category missing" do
      attrs = %{title: "Title", body: "Content"}
      assert {:error, :invalid_category} = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end

    test "returns {:error, :title_too_long} for title > 255 chars" do
      long_title = String.duplicate("x", 256)
      attrs = %{title: long_title, body: "Content", category: "how_to"}
      assert {:error, :title_too_long} = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end

    test "accepts title of exactly 255 chars" do
      title = String.duplicate("x", 255)
      attrs = %{title: title, body: "Content", category: "how_to"}
      assert :ok = KnowledgeValidationPolicy.validate_entry_attrs(attrs)
    end
  end

  describe "validate_update_attrs/1" do
    test "returns :ok for partial updates (no required fields)" do
      attrs = %{title: "Updated title"}
      assert :ok = KnowledgeValidationPolicy.validate_update_attrs(attrs)
    end

    test "returns :ok for empty update" do
      assert :ok = KnowledgeValidationPolicy.validate_update_attrs(%{})
    end

    test "returns {:error, :invalid_category} if category present but invalid" do
      attrs = %{category: "not_valid"}
      assert {:error, :invalid_category} = KnowledgeValidationPolicy.validate_update_attrs(attrs)
    end

    test "returns :ok when category is valid" do
      attrs = %{category: "pattern"}
      assert :ok = KnowledgeValidationPolicy.validate_update_attrs(attrs)
    end

    test "returns {:error, :title_too_long} for title > 255 chars" do
      attrs = %{title: String.duplicate("x", 256)}
      assert {:error, :title_too_long} = KnowledgeValidationPolicy.validate_update_attrs(attrs)
    end
  end

  describe "validate_tags/1" do
    test "returns :ok for valid tag list" do
      assert :ok = KnowledgeValidationPolicy.validate_tags(["elixir", "testing"])
    end

    test "returns :ok for empty list" do
      assert :ok = KnowledgeValidationPolicy.validate_tags([])
    end

    test "returns {:error, :too_many_tags} for > 20 tags" do
      tags = Enum.map(1..21, &"tag-#{&1}")
      assert {:error, :too_many_tags} = KnowledgeValidationPolicy.validate_tags(tags)
    end

    test "returns {:error, :invalid_tag} for empty string tags" do
      assert {:error, :invalid_tag} = KnowledgeValidationPolicy.validate_tags(["valid", ""])
    end
  end

  describe "validate_self_reference/2" do
    test "returns :ok when from_id != to_id" do
      assert :ok = KnowledgeValidationPolicy.validate_self_reference("a", "b")
    end

    test "returns {:error, :self_reference} when from_id == to_id" do
      assert {:error, :self_reference} =
               KnowledgeValidationPolicy.validate_self_reference("a", "a")
    end
  end

  describe "categories/0" do
    test "returns the list of all valid categories" do
      categories = KnowledgeValidationPolicy.categories()
      assert is_list(categories)
      assert length(categories) == 6
      assert "how_to" in categories
      assert "architecture_decision" in categories
    end
  end

  describe "relationship_types/0" do
    test "returns the list of all valid relationship types" do
      types = KnowledgeValidationPolicy.relationship_types()
      assert is_list(types)
      assert length(types) == 6
      assert "relates_to" in types
      assert "supersedes" in types
    end
  end
end
