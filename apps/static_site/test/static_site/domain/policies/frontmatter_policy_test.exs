defmodule StaticSite.Domain.Policies.FrontmatterPolicyTest do
  use ExUnit.Case, async: true

  alias StaticSite.Domain.Policies.FrontmatterPolicy

  describe "validate_frontmatter/1" do
    test "validates frontmatter with all required fields" do
      frontmatter = %{
        "title" => "My Post",
        "date" => "2024-01-15T10:30:00Z",
        "tags" => ["elixir", "blog"],
        "draft" => false
      }

      assert {:ok, ^frontmatter} = FrontmatterPolicy.validate_frontmatter(frontmatter)
    end

    test "validates frontmatter with only title (minimum requirement)" do
      frontmatter = %{"title" => "Simple Post"}

      assert {:ok, ^frontmatter} = FrontmatterPolicy.validate_frontmatter(frontmatter)
    end

    test "fails when title is missing" do
      frontmatter = %{"date" => "2024-01-15T10:30:00Z"}

      assert {:error, errors} = FrontmatterPolicy.validate_frontmatter(frontmatter)
      assert "Missing required field 'title'" in errors
    end

    test "fails when title is empty string" do
      frontmatter = %{"title" => ""}

      assert {:error, errors} = FrontmatterPolicy.validate_frontmatter(frontmatter)
      assert "title cannot be empty" in errors
    end

    test "validates date field is ISO 8601 format" do
      frontmatter = %{
        "title" => "Post",
        "date" => "2024-01-15T10:30:00Z"
      }

      assert {:ok, ^frontmatter} = FrontmatterPolicy.validate_frontmatter(frontmatter)
    end

    test "fails when date is invalid ISO 8601" do
      frontmatter = %{
        "title" => "Post",
        "date" => "not-a-date"
      }

      assert {:error, errors} = FrontmatterPolicy.validate_frontmatter(frontmatter)
      # Check that error message contains the expected format
      assert Enum.any?(errors, &String.contains?(&1, "Invalid date format, expected ISO 8601"))
    end

    test "validates tags field is a list" do
      frontmatter = %{
        "title" => "Post",
        "tags" => ["elixir", "phoenix"]
      }

      assert {:ok, ^frontmatter} = FrontmatterPolicy.validate_frontmatter(frontmatter)
    end

    test "fails when tags is not a list" do
      frontmatter = %{
        "title" => "Post",
        "tags" => "not-a-list"
      }

      assert {:error, errors} = FrontmatterPolicy.validate_frontmatter(frontmatter)
      assert "Tags must be a list of strings" in errors
    end

    test "validates draft field is boolean" do
      frontmatter = %{
        "title" => "Post",
        "draft" => true
      }

      assert {:ok, ^frontmatter} = FrontmatterPolicy.validate_frontmatter(frontmatter)
    end

    test "fails when draft is not boolean" do
      frontmatter = %{
        "title" => "Post",
        "draft" => "yes"
      }

      assert {:error, errors} = FrontmatterPolicy.validate_frontmatter(frontmatter)
      assert "draft must be a boolean" in errors
    end

    test "accumulates multiple validation errors" do
      frontmatter = %{
        "date" => "invalid",
        "tags" => "not-a-list",
        "draft" => "not-boolean"
      }

      assert {:error, errors} = FrontmatterPolicy.validate_frontmatter(frontmatter)
      assert "Missing required field 'title'" in errors
      assert Enum.any?(errors, &String.contains?(&1, "Invalid date format, expected ISO 8601"))
      assert "Tags must be a list of strings" in errors
      assert "draft must be a boolean" in errors
    end

    test "allows custom fields" do
      frontmatter = %{
        "title" => "Post",
        "author" => "John Doe",
        "custom_field" => "value"
      }

      assert {:ok, ^frontmatter} = FrontmatterPolicy.validate_frontmatter(frontmatter)
    end
  end
end
