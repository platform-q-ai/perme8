defmodule Alkali.Domain.Policies.SlugPolicyTest do
  use ExUnit.Case, async: true

  alias Alkali.Domain.Policies.SlugPolicy

  describe "generate_slug/1" do
    test "converts title to lowercase slug" do
      assert SlugPolicy.generate_slug("My First Post") == "my-first-post"
    end

    test "replaces spaces with hyphens" do
      assert SlugPolicy.generate_slug("Hello World Test") == "hello-world-test"
    end

    test "removes special characters" do
      assert SlugPolicy.generate_slug("Post: Part 1 (Updated!)") == "post-part-1-updated"
    end

    test "handles unicode characters" do
      assert SlugPolicy.generate_slug("Café & Résumé") == "cafe-resume"
    end

    test "removes punctuation" do
      assert SlugPolicy.generate_slug("What's New? Here it is!") == "whats-new-here-it-is"
    end

    test "collapses multiple hyphens" do
      assert SlugPolicy.generate_slug("Too  Many   Spaces") == "too-many-spaces"
    end

    test "trims leading and trailing hyphens" do
      assert SlugPolicy.generate_slug("  Leading and Trailing  ") == "leading-and-trailing"
    end

    test "handles numbers" do
      assert SlugPolicy.generate_slug("Article 2024: Part 1") == "article-2024-part-1"
    end

    test "handles all caps" do
      assert SlugPolicy.generate_slug("HTML AND CSS") == "html-and-css"
    end

    test "handles empty string" do
      assert SlugPolicy.generate_slug("") == ""
    end

    test "handles only special characters" do
      assert SlugPolicy.generate_slug("!!!???") == ""
    end
  end
end
