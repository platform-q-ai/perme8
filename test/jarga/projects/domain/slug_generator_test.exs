defmodule Jarga.Projects.Domain.SlugGeneratorTest do
  use ExUnit.Case, async: true

  alias Jarga.Projects.Domain.SlugGenerator

  @workspace_id "workspace-123"

  describe "generate/4" do
    test "generates a simple slug from a name" do
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result = SlugGenerator.generate("My Project", @workspace_id, uniqueness_checker)

      assert result == "my-project"
    end

    test "converts spaces to hyphens" do
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result = SlugGenerator.generate("Multiple Word Project", @workspace_id, uniqueness_checker)

      assert result == "multiple-word-project"
    end

    test "removes special characters" do
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result =
        SlugGenerator.generate("Special!@# Characters$%", @workspace_id, uniqueness_checker)

      assert result == "special-characters"
    end

    test "converts to lowercase" do
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result = SlugGenerator.generate("UPPERCASE", @workspace_id, uniqueness_checker)

      assert result == "uppercase"
    end

    test "handles unicode characters" do
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result = SlugGenerator.generate("Café résumé", @workspace_id, uniqueness_checker)

      assert result == "cafe-resume"
    end

    test "trims trailing hyphens" do
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result = SlugGenerator.generate("Trailing---", @workspace_id, uniqueness_checker)

      assert result == "trailing"
    end

    test "handles empty string" do
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result = SlugGenerator.generate("", @workspace_id, uniqueness_checker)

      assert result == ""
    end
  end

  describe "generate/4 - workspace scoping" do
    test "passes workspace_id to uniqueness checker" do
      workspace_id = "my-workspace-id"
      test_pid = self()

      uniqueness_checker = fn _slug, received_workspace_id, _excluding_id ->
        send(test_pid, {:workspace_id, received_workspace_id})
        false
      end

      SlugGenerator.generate("Test", workspace_id, uniqueness_checker)

      assert_receive {:workspace_id, ^workspace_id}
    end

    test "slugs are scoped per workspace" do
      # Same slug can exist in different workspaces
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result1 = SlugGenerator.generate("Project", "workspace-1", uniqueness_checker)
      result2 = SlugGenerator.generate("Project", "workspace-2", uniqueness_checker)

      assert result1 == "project"
      assert result2 == "project"
    end
  end

  describe "generate/4 - uniqueness" do
    test "returns slug when it's unique" do
      uniqueness_checker = fn _slug, _workspace_id, _excluding_id -> false end

      result = SlugGenerator.generate("Unique", @workspace_id, uniqueness_checker)

      assert result == "unique"
    end

    test "adds random suffix when slug is not unique" do
      # First call returns true (not unique), second call returns false (unique)
      call_count = :counters.new(1, [])

      uniqueness_checker = fn _slug, _workspace_id, _excluding_id ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)
        count == 0
      end

      result = SlugGenerator.generate("Duplicate", @workspace_id, uniqueness_checker)

      assert result != "duplicate"
      assert String.starts_with?(result, "duplicate-")
      # Random suffix should be 6 hex characters
      [_base, suffix] = String.split(result, "-", parts: 2)
      assert String.length(suffix) == 6
      assert String.match?(suffix, ~r/^[0-9a-f]{6}$/)
    end

    test "keeps adding suffix until unique" do
      # First two calls return true (not unique), third call returns false (unique)
      call_count = :counters.new(1, [])

      uniqueness_checker = fn _slug, _workspace_id, _excluding_id ->
        count = :counters.get(call_count, 1)
        :counters.add(call_count, 1, 1)
        count < 2
      end

      result = SlugGenerator.generate("Duplicate", @workspace_id, uniqueness_checker)

      assert result != "duplicate"
      assert String.starts_with?(result, "duplicate-")
    end

    test "passes excluding_id to uniqueness checker" do
      excluding_id = "some-id-123"
      test_pid = self()

      uniqueness_checker = fn _slug, _workspace_id, received_excluding_id ->
        send(test_pid, {:excluding_id, received_excluding_id})
        false
      end

      SlugGenerator.generate("Test", @workspace_id, uniqueness_checker, excluding_id)

      assert_receive {:excluding_id, ^excluding_id}
    end

    test "passes nil as excluding_id when not provided" do
      test_pid = self()

      uniqueness_checker = fn _slug, _workspace_id, received_excluding_id ->
        send(test_pid, {:excluding_id, received_excluding_id})
        false
      end

      SlugGenerator.generate("Test", @workspace_id, uniqueness_checker)

      assert_receive {:excluding_id, nil}
    end

    test "passes generated slug to uniqueness checker" do
      test_pid = self()

      uniqueness_checker = fn received_slug, _workspace_id, _excluding_id ->
        send(test_pid, {:slug, received_slug})
        false
      end

      SlugGenerator.generate("My Project", @workspace_id, uniqueness_checker)

      assert_receive {:slug, "my-project"}
    end
  end
end
