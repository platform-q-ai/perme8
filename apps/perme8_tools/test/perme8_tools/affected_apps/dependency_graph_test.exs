defmodule Perme8Tools.AffectedApps.DependencyGraphTest do
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.DependencyGraph

  @simple_deps %{
    a: [:b, :c],
    b: [:c],
    c: [],
    d: []
  }

  @perme8_deps %{
    perme8_events: [],
    perme8_plugs: [],
    identity: [:perme8_events, :perme8_plugs],
    agents: [:perme8_events, :perme8_plugs, :identity],
    notifications: [:perme8_events, :identity],
    chat: [:perme8_events, :identity, :agents],
    jarga: [:perme8_events, :identity, :agents, :notifications],
    entity_relationship_manager: [:perme8_events, :perme8_plugs, :jarga, :identity],
    webhooks: [:perme8_events, :identity, :jarga],
    jarga_web: [:perme8_events, :perme8_plugs, :jarga, :agents, :notifications, :chat, :chat_web],
    jarga_api: [:jarga, :identity, :perme8_plugs],
    agents_web: [:perme8_events, :agents, :identity, :jarga],
    agents_api: [:agents, :identity, :perme8_plugs],
    chat_web: [:chat, :identity, :agents],
    webhooks_api: [:webhooks, :identity, :jarga, :perme8_plugs],
    exo_dashboard: [],
    perme8_dashboard: [:exo_dashboard, :agents_web, :identity, :jarga],
    alkali: [],
    perme8_tools: []
  }

  describe "build/1" do
    test "creates a graph from a dependency map" do
      assert {:ok, graph} = DependencyGraph.build(@simple_deps)
      assert %DependencyGraph{} = graph
    end

    test "all apps are present in the graph" do
      {:ok, graph} = DependencyGraph.build(@simple_deps)
      assert DependencyGraph.all_apps(graph) == MapSet.new([:a, :b, :c, :d])
    end

    test "builds successfully with the full Perme8 dependency map" do
      assert {:ok, graph} = DependencyGraph.build(@perme8_deps)
      assert MapSet.size(DependencyGraph.all_apps(graph)) == 19
    end

    test "detects circular dependencies" do
      circular = %{a: [:b], b: [:c], c: [:a]}
      assert {:error, :circular_dependency, cycle} = DependencyGraph.build(circular)
      assert is_list(cycle)
      assert length(cycle) >= 2
    end

    test "detects simple two-node cycle" do
      circular = %{a: [:b], b: [:a]}
      assert {:error, :circular_dependency, _cycle} = DependencyGraph.build(circular)
    end

    test "builds successfully with empty deps map" do
      assert {:ok, graph} = DependencyGraph.build(%{})
      assert DependencyGraph.all_apps(graph) == MapSet.new()
    end
  end

  describe "direct_dependents/2" do
    test "returns apps that directly depend on a given app" do
      {:ok, graph} = DependencyGraph.build(@simple_deps)
      # a depends on b, so b's direct dependents include a
      assert MapSet.member?(DependencyGraph.direct_dependents(graph, :b), :a)
    end

    test "returns empty set for app with no dependents" do
      {:ok, graph} = DependencyGraph.build(@simple_deps)
      assert DependencyGraph.direct_dependents(graph, :a) == MapSet.new()
      assert DependencyGraph.direct_dependents(graph, :d) == MapSet.new()
    end

    test "identity has many direct dependents in Perme8 graph" do
      {:ok, graph} = DependencyGraph.build(@perme8_deps)
      dependents = DependencyGraph.direct_dependents(graph, :identity)
      assert :agents in dependents
      assert :notifications in dependents
      assert :chat in dependents
      assert :jarga in dependents
    end
  end

  describe "transitive_dependents/2" do
    test "returns all transitive dependents" do
      {:ok, graph} = DependencyGraph.build(@simple_deps)
      # c is depended on by b and a (transitively through b)
      dependents = DependencyGraph.transitive_dependents(graph, :c)
      assert :a in dependents
      assert :b in dependents
    end

    test "leaf app has no transitive dependents" do
      {:ok, graph} = DependencyGraph.build(@simple_deps)
      assert DependencyGraph.transitive_dependents(graph, :a) == MapSet.new()
      assert DependencyGraph.transitive_dependents(graph, :d) == MapSet.new()
    end

    test "alkali has no dependents in Perme8 graph" do
      {:ok, graph} = DependencyGraph.build(@perme8_deps)
      assert DependencyGraph.transitive_dependents(graph, :alkali) == MapSet.new()
    end

    test "perme8_events propagates to most apps" do
      {:ok, graph} = DependencyGraph.build(@perme8_deps)
      dependents = DependencyGraph.transitive_dependents(graph, :perme8_events)

      assert :identity in dependents
      assert :agents in dependents
      assert :jarga in dependents
      assert :chat in dependents
      assert :jarga_web in dependents
      assert :agents_web in dependents
      assert :webhooks in dependents
      assert :webhooks_api in dependents
      assert :perme8_dashboard in dependents

      # Should NOT include apps with no dependency path
      refute :alkali in dependents
      refute :perme8_tools in dependents
      refute :exo_dashboard in dependents
    end

    test "identity propagates transitively to all dependent apps" do
      {:ok, graph} = DependencyGraph.build(@perme8_deps)
      dependents = DependencyGraph.transitive_dependents(graph, :identity)

      # Direct dependents
      assert :agents in dependents
      assert :notifications in dependents
      assert :chat in dependents
      assert :jarga in dependents

      # Transitive dependents
      assert :jarga_web in dependents
      assert :jarga_api in dependents
      assert :agents_web in dependents
      assert :agents_api in dependents
      assert :chat_web in dependents
      assert :webhooks in dependents
      assert :webhooks_api in dependents
      assert :entity_relationship_manager in dependents
      assert :perme8_dashboard in dependents
    end

    test "jarga_web has no dependents (leaf interface app)" do
      {:ok, graph} = DependencyGraph.build(@perme8_deps)
      # jarga_web is a leaf - nothing depends on it
      assert DependencyGraph.transitive_dependents(graph, :jarga_web) == MapSet.new()
    end
  end

  describe "dependencies/2" do
    test "returns direct dependencies of an app" do
      {:ok, graph} = DependencyGraph.build(@simple_deps)
      assert DependencyGraph.dependencies(graph, :a) == MapSet.new([:b, :c])
    end

    test "returns empty set for app with no dependencies" do
      {:ok, graph} = DependencyGraph.build(@simple_deps)
      assert DependencyGraph.dependencies(graph, :c) == MapSet.new()
    end

    test "returns empty for unknown app" do
      {:ok, graph} = DependencyGraph.build(@simple_deps)
      assert DependencyGraph.dependencies(graph, :unknown) == MapSet.new()
    end
  end
end
