defmodule Perme8Tools.AffectedApps.TestPathsTest do
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.TestPaths

  describe "unit_test_paths/2" do
    test "returns sorted test paths for affected apps" do
      apps = MapSet.new([:identity, :agents])
      paths = TestPaths.unit_test_paths(apps)

      assert paths == ["apps/agents/test", "apps/identity/test"]
    end

    test "handles single app" do
      apps = MapSet.new([:jarga_web])
      paths = TestPaths.unit_test_paths(apps)

      assert paths == ["apps/jarga_web/test"]
    end

    test "returns empty list for all_apps option" do
      apps = MapSet.new([:identity])
      paths = TestPaths.unit_test_paths(apps, all_apps?: true)

      assert paths == []
    end

    test "returns empty list for empty affected set" do
      paths = TestPaths.unit_test_paths(MapSet.new())

      assert paths == []
    end

    test "handles entity_relationship_manager correctly" do
      apps = MapSet.new([:entity_relationship_manager])
      paths = TestPaths.unit_test_paths(apps)

      assert paths == ["apps/entity_relationship_manager/test"]
    end

    test "sorts paths alphabetically" do
      apps = MapSet.new([:webhooks_api, :alkali, :jarga])
      paths = TestPaths.unit_test_paths(apps)

      assert paths == ["apps/alkali/test", "apps/jarga/test", "apps/webhooks_api/test"]
    end
  end

  describe "mix_test_command/2" do
    test "generates command with test paths" do
      apps = MapSet.new([:identity, :agents])
      command = TestPaths.mix_test_command(apps)

      assert command == "mix test apps/agents/test apps/identity/test"
    end

    test "returns 'mix test' for all_apps option" do
      command = TestPaths.mix_test_command(MapSet.new(), all_apps?: true)

      assert command == "mix test"
    end

    test "returns nil for empty affected set" do
      command = TestPaths.mix_test_command(MapSet.new())

      assert command == nil
    end

    test "handles single app" do
      apps = MapSet.new([:alkali])
      command = TestPaths.mix_test_command(apps)

      assert command == "mix test apps/alkali/test"
    end
  end
end
