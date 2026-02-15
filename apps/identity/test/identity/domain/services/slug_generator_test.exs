defmodule Identity.Domain.Services.SlugGeneratorTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Services.SlugGenerator

  describe "generate/3" do
    test "generates a simple slug from a name" do
      uniqueness_checker = fn _slug, _excluding_id -> false end

      result = SlugGenerator.generate("My Workspace", uniqueness_checker)

      assert result == "my-workspace"
    end

    test "converts spaces to hyphens" do
      uniqueness_checker = fn _slug, _excluding_id -> false end

      result = SlugGenerator.generate("Multiple Word Workspace", uniqueness_checker)

      assert result == "multiple-word-workspace"
    end

    test "removes special characters" do
      uniqueness_checker = fn _slug, _excluding_id -> false end

      result = SlugGenerator.generate("Special!@# Characters$%", uniqueness_checker)

      assert result == "special-characters"
    end

    test "converts to lowercase" do
      uniqueness_checker = fn _slug, _excluding_id -> false end

      result = SlugGenerator.generate("UPPERCASE", uniqueness_checker)

      assert result == "uppercase"
    end

    test "strips trailing hyphens" do
      uniqueness_checker = fn _slug, _excluding_id -> false end

      result = SlugGenerator.generate("Trailing---", uniqueness_checker)

      assert result == "trailing"
    end

    test "handles unicode characters" do
      uniqueness_checker = fn _slug, _excluding_id -> false end

      result = SlugGenerator.generate("Café résumé", uniqueness_checker)

      assert result == "cafe-resume"
    end
  end

  describe "generate/3 - uniqueness" do
    test "returns slug when it is unique" do
      uniqueness_checker = fn _slug, _excluding_id -> false end

      result = SlugGenerator.generate("Unique", uniqueness_checker)

      assert result == "unique"
    end

    test "appends random suffix when slug already exists" do
      # First call returns true (not unique), second call returns false (unique)
      call_count = :counters.new(1, [])

      uniqueness_checker = fn _slug, _excluding_id ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)
        count == 0
      end

      result = SlugGenerator.generate("Duplicate", uniqueness_checker)

      assert result != "duplicate"
      assert String.starts_with?(result, "duplicate-")
      # Random suffix should be 6 hex characters
      [_base, suffix] = String.split(result, "-", parts: 2)
      assert String.length(suffix) == 6
      assert String.match?(suffix, ~r/^[0-9a-f]{6}$/)
    end

    test "respects excluding_id parameter" do
      excluding_id = "some-id-123"
      test_pid = self()

      uniqueness_checker = fn _slug, received_excluding_id ->
        send(test_pid, {:excluding_id, received_excluding_id})
        false
      end

      SlugGenerator.generate("Test", uniqueness_checker, excluding_id)

      assert_receive {:excluding_id, ^excluding_id}
    end

    test "passes nil as excluding_id when not provided" do
      test_pid = self()

      uniqueness_checker = fn _slug, received_excluding_id ->
        send(test_pid, {:excluding_id, received_excluding_id})
        false
      end

      SlugGenerator.generate("Test", uniqueness_checker)

      assert_receive {:excluding_id, nil}
    end
  end
end
