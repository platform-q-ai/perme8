defmodule Perme8Tools.AffectedApps.CiParityTest do
  @moduledoc """
  Validates that the Elixir affected-apps calculation produces results
  consistent with the CI Python selective matrix logic.

  Documents intentional improvements (transitive dependency propagation)
  over the current CI Python implementation.
  """
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.{
    AffectedCalculator,
    DependencyGraph,
    ExoBddMapping,
    FileClassifier,
    Fixtures
  }

  @perme8_deps Fixtures.perme8_deps()
  @known_apps Fixtures.known_apps()

  setup do
    {:ok, graph} = DependencyGraph.build(@perme8_deps)
    %{graph: graph}
  end

  defp compute_exo_combos(changed_files, graph) do
    classification = FileClassifier.classify_all(changed_files, @known_apps)
    result = AffectedCalculator.calculate(classification, graph)

    ExoBddMapping.exo_bdd_combos(result.affected_apps, all_exo_bdd?: result.all_exo_bdd?)
  end

  describe "CI parity: domain-to-surface mapping" do
    test "jarga change -> jarga-web, jarga-api, erm combos (matches Python)", %{graph: graph} do
      combos = compute_exo_combos(["apps/jarga/lib/jarga.ex"], graph)
      apps = Enum.map(combos, & &1.app) |> Enum.uniq() |> Enum.sort()

      assert "jarga-web" in apps
      assert "jarga-api" in apps
      assert "erm" in apps
    end

    test "webhooks change -> webhooks-api combos (matches Python)", %{graph: graph} do
      combos = compute_exo_combos(["apps/webhooks/lib/webhooks.ex"], graph)
      apps = Enum.map(combos, & &1.app) |> Enum.uniq()

      assert "webhooks-api" in apps
    end

    test "agents change -> agents http+security combos (matches Python)", %{graph: graph} do
      combos = compute_exo_combos(["apps/agents/lib/agents.ex"], graph)
      agents_combos = Enum.filter(combos, &(&1.app == "agents"))
      domains = Enum.map(agents_combos, & &1.domain) |> Enum.sort()

      assert "http" in domains
      assert "security" in domains
    end

    test "identity change -> identity browser+security combos (matches Python)", %{graph: graph} do
      combos = compute_exo_combos(["apps/identity/lib/identity.ex"], graph)
      identity_combos = Enum.filter(combos, &(&1.app == "identity"))
      domains = Enum.map(identity_combos, & &1.domain) |> Enum.sort()

      assert "browser" in domains
      assert "security" in domains
    end

    test "exo_dashboard change -> exo-dashboard combos (matches Python)", %{graph: graph} do
      combos = compute_exo_combos(["apps/exo_dashboard/lib/exo_dashboard.ex"], graph)
      apps = Enum.map(combos, & &1.app) |> Enum.uniq()

      assert "exo-dashboard" in apps
    end

    test "perme8_dashboard change -> perme8-dashboard combos (matches Python)", %{graph: graph} do
      combos = compute_exo_combos(["apps/perme8_dashboard/lib/perme8_dashboard.ex"], graph)
      apps = Enum.map(combos, & &1.app) |> Enum.uniq()

      assert "perme8-dashboard" in apps
    end
  end

  describe "CI parity: trigger-all scenarios" do
    test "shared config change -> all combos (matches Python is_main/shared_changed)", %{
      graph: graph
    } do
      combos = compute_exo_combos(["config/config.exs"], graph)
      assert length(combos) == 20
    end

    test "tools/exo-bdd change -> all combos (matches Python exo_bdd_changed)", %{graph: graph} do
      combos = compute_exo_combos(["tools/exo-bdd/src/runner.ts"], graph)
      assert length(combos) == 20
    end
  end

  describe "IMPROVEMENT over CI Python: transitive dependency propagation" do
    @tag :improvement
    test "identity change also includes agents-web, agents-api via transitive deps", %{
      graph: graph
    } do
      # The Python CI only does direct file-path matching.
      # Our Elixir implementation propagates transitively.
      combos = compute_exo_combos(["apps/identity/lib/identity.ex"], graph)
      apps = Enum.map(combos, & &1.app) |> Enum.uniq()

      # These are transitively affected -- agents depends on identity,
      # agents-web depends on agents
      assert "agents-web" in apps
      assert "agents-api" in apps
      assert "agents" in apps
    end

    @tag :improvement
    test "perme8_events change propagates to most exo-bdd surfaces", %{graph: graph} do
      # In CI Python, perme8_events isn't even tracked by dorny paths-filter.
      # Our implementation correctly propagates through the dependency graph.
      combos = compute_exo_combos(["apps/perme8_events/lib/perme8_events.ex"], graph)
      apps = Enum.map(combos, & &1.app) |> Enum.uniq()

      assert "identity" in apps
      assert "agents" in apps
      assert "jarga-web" in apps
      assert "jarga-api" in apps
    end
  end
end
