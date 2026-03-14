defmodule Perme8Tools.AffectedApps.ExoBddMappingTest do
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.ExoBddMapping

  describe "all_combos/0" do
    test "returns 20 combos matching CI ALL_COMBOS" do
      combos = ExoBddMapping.all_combos()
      assert length(combos) == 20
    end

    test "each combo has required keys" do
      for combo <- ExoBddMapping.all_combos() do
        assert Map.has_key?(combo, :app)
        assert Map.has_key?(combo, :domain)
        assert Map.has_key?(combo, :config_name)
        assert Map.has_key?(combo, :timeout)
      end
    end

    test "includes expected apps" do
      apps = ExoBddMapping.all_combos() |> Enum.map(& &1.app) |> Enum.uniq() |> Enum.sort()

      assert apps == [
               "agents",
               "agents-api",
               "agents-web",
               "alkali",
               "erm",
               "exo-dashboard",
               "identity",
               "jarga-api",
               "jarga-web",
               "perme8-dashboard",
               "webhooks-api"
             ]
    end
  end

  describe "exo_bdd_combos/2" do
    test "identity returns browser and security combos" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:identity]))

      assert length(combos) == 2
      domains = Enum.map(combos, & &1.domain) |> Enum.sort()
      assert domains == ["browser", "security"]
      assert Enum.all?(combos, &(&1.app == "identity"))
    end

    test "jarga fans out to jarga-web, jarga-api, erm combos" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:jarga]))

      apps = Enum.map(combos, & &1.app) |> Enum.uniq() |> Enum.sort()
      assert apps == ["erm", "jarga-api", "jarga-web"]
      # 6 combos: jarga-web(browser+security) + jarga-api(http+security) + erm(http+security)
      assert length(combos) == 6
    end

    test "webhooks fans out to webhooks-api combos" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:webhooks]))

      assert length(combos) == 2
      assert Enum.all?(combos, &(&1.app == "webhooks-api"))
      domains = Enum.map(combos, & &1.domain) |> Enum.sort()
      assert domains == ["http", "security"]
    end

    test "agents returns agents combos (has own exo-bdd)" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:agents]))

      agents_combos = Enum.filter(combos, &(&1.app == "agents"))
      assert length(agents_combos) == 2
      domains = Enum.map(agents_combos, & &1.domain) |> Enum.sort()
      assert domains == ["http", "security"]
    end

    test "jarga_web returns jarga-web combos" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:jarga_web]))

      assert length(combos) == 2
      assert Enum.all?(combos, &(&1.app == "jarga-web"))
    end

    test "alkali returns cli combo" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:alkali]))

      assert combos == [%{app: "alkali", domain: "cli", config_name: "alkali", timeout: 5}]
    end

    test "all_exo_bdd option returns all combos" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new(), all_exo_bdd?: true)
      assert length(combos) == 20
    end

    test "perme8_tools has no exo-bdd combos" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:perme8_tools]))
      assert combos == []
    end

    test "deduplicates when jarga and jarga_web both affected" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:jarga, :jarga_web]))

      # jarga fans out to jarga-web, jarga-api, erm
      # jarga_web maps directly to jarga-web
      # jarga-web should appear only once per domain
      jarga_web_combos = Enum.filter(combos, &(&1.app == "jarga-web"))
      assert length(jarga_web_combos) == 2

      # Total: jarga-web(2) + jarga-api(2) + erm(2)
      assert length(combos) == 6
    end

    test "empty affected apps returns empty list" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new())
      assert combos == []
    end

    test "combo config_name matches expected values" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:entity_relationship_manager]))

      assert length(combos) == 2
      assert Enum.all?(combos, &(&1.config_name == "entity-relationship-manager"))
    end

    test "combo timeouts match CI values" do
      combos = ExoBddMapping.exo_bdd_combos(MapSet.new([:identity]))
      browser = Enum.find(combos, &(&1.domain == "browser"))
      security = Enum.find(combos, &(&1.domain == "security"))

      assert browser.timeout == 15
      assert security.timeout == 20
    end
  end
end
