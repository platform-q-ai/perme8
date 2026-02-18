defmodule Mix.Tasks.Check.CiSyncTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Check.CiSync

  # The umbrella root: test/mix/tasks -> ../../../../../ (5 levels up to perme8/)
  @umbrella_root Path.expand("../../../../..", __DIR__)

  describe "parse_ci_combos/1" do
    test "extracts all config_name+domain pairs from CI matrix" do
      combos = CiSync.parse_ci_combos(@umbrella_root)

      # Verify known combos exist (these are stable entries in ALL_COMBOS)
      assert MapSet.member?(combos, {"alkali", "cli"})
      assert MapSet.member?(combos, {"entity-relationship-manager", "http"})
      assert MapSet.member?(combos, {"entity-relationship-manager", "security"})
      assert MapSet.member?(combos, {"identity", "browser"})
      assert MapSet.member?(combos, {"identity", "security"})
      assert MapSet.member?(combos, {"jarga-api", "http"})
      assert MapSet.member?(combos, {"jarga-api", "security"})
      assert MapSet.member?(combos, {"jarga-web", "browser"})
      assert MapSet.member?(combos, {"jarga-web", "security"})

      # Should have at least 9 entries
      assert MapSet.size(combos) >= 9
    end

    test "pairs config_name and domain correctly regardless of field order" do
      # Verifies the parser handles entries where domain appears before config_name
      combos = CiSync.parse_ci_combos(@umbrella_root)

      # ERM uses a different config_name than app name -- verifies correct pairing
      assert MapSet.member?(combos, {"entity-relationship-manager", "http"})
      refute MapSet.member?(combos, {"erm", "http"})
    end
  end

  describe "discover_disk_combos/2" do
    test "finds combos for configs with matching feature files" do
      configs = [Path.join(@umbrella_root, "apps/jarga_web/test/exo-bdd-jarga-web.config.ts")]
      combos = CiSync.discover_disk_combos(configs, @umbrella_root)

      assert MapSet.member?(combos, {"jarga-web", "browser"})
      assert MapSet.member?(combos, {"jarga-web", "security"})
    end

    test "returns empty set for nonexistent config paths" do
      combos = CiSync.discover_disk_combos(["/nonexistent/config.ts"], "/nonexistent")
      assert MapSet.size(combos) == 0
    end
  end
end
