defmodule Perme8Tools.AffectedApps.DiffProviderTest do
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.DiffProvider

  describe "from_args/1" do
    test "returns the provided file paths" do
      args = ["apps/identity/lib/identity.ex", "config/config.exs"]
      assert DiffProvider.from_args(args) == args
    end

    test "strips whitespace" do
      args = ["  apps/identity/lib/identity.ex  ", "config/config.exs\n"]

      assert DiffProvider.from_args(args) == [
               "apps/identity/lib/identity.ex",
               "config/config.exs"
             ]
    end

    test "removes empty strings" do
      args = ["apps/identity/lib/identity.ex", "", "  "]
      assert DiffProvider.from_args(args) == ["apps/identity/lib/identity.ex"]
    end

    test "returns empty list for empty args" do
      assert DiffProvider.from_args([]) == []
    end
  end

  describe "from_git_diff/2" do
    test "returns files from successful git diff" do
      mock_cmd = fn "git", ["diff", "--name-only", "main...HEAD"], _opts ->
        {"apps/identity/lib/identity.ex\nconfig/config.exs\n", 0}
      end

      assert {:ok, files} = DiffProvider.from_git_diff("main", system_cmd: mock_cmd)
      assert files == ["apps/identity/lib/identity.ex", "config/config.exs"]
    end

    test "returns error on git failure" do
      mock_cmd = fn "git", ["diff", "--name-only", "nonexistent...HEAD"], _opts ->
        {"fatal: ambiguous argument 'nonexistent...HEAD'", 128}
      end

      assert {:error, msg} = DiffProvider.from_git_diff("nonexistent", system_cmd: mock_cmd)
      assert msg =~ "fatal"
    end

    test "strips empty lines from git output" do
      mock_cmd = fn "git", ["diff", "--name-only", "main...HEAD"], _opts ->
        {"apps/identity/lib/identity.ex\n\n\n", 0}
      end

      assert {:ok, files} = DiffProvider.from_git_diff("main", system_cmd: mock_cmd)
      assert files == ["apps/identity/lib/identity.ex"]
    end

    test "returns empty list when no changes" do
      mock_cmd = fn "git", ["diff", "--name-only", "main...HEAD"], _opts ->
        {"", 0}
      end

      assert {:ok, []} = DiffProvider.from_git_diff("main", system_cmd: mock_cmd)
    end
  end

  describe "from_stdin/1" do
    test "reads from injected IO device" do
      {:ok, device} = StringIO.open("apps/identity/lib/identity.ex\nconfig/config.exs\n")

      files = DiffProvider.from_stdin(io_device: device)
      assert files == ["apps/identity/lib/identity.ex", "config/config.exs"]
    end

    test "strips empty lines" do
      {:ok, device} = StringIO.open("apps/identity/lib/identity.ex\n\n\n")

      files = DiffProvider.from_stdin(io_device: device)
      assert files == ["apps/identity/lib/identity.ex"]
    end

    test "returns empty list for empty input" do
      {:ok, device} = StringIO.open("")

      files = DiffProvider.from_stdin(io_device: device)
      assert files == []
    end
  end
end
