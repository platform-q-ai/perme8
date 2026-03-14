defmodule Perme8Tools.AffectedApps.GraphDiscoveryTest do
  # NOT async -- reads real files from disk
  use ExUnit.Case, async: false

  alias Perme8Tools.AffectedApps.{GraphDiscovery, DependencyGraph}

  @umbrella_root Path.expand("../../../../..", __DIR__)

  describe "discover_apps/1" do
    test "finds all umbrella apps" do
      apps = GraphDiscovery.discover_apps(@umbrella_root)

      assert :identity in apps
      assert :agents in apps
      assert :jarga in apps
      assert :perme8_tools in apps
      assert :alkali in apps
      assert :perme8_events in apps
    end

    test "discovers the expected number of apps (19)" do
      apps = GraphDiscovery.discover_apps(@umbrella_root)
      assert length(apps) == 19
    end

    test "returns sorted list" do
      apps = GraphDiscovery.discover_apps(@umbrella_root)
      assert apps == Enum.sort(apps)
    end

    test "handles entity_relationship_manager" do
      apps = GraphDiscovery.discover_apps(@umbrella_root)
      assert :entity_relationship_manager in apps
    end

    test "returns empty list for non-existent directory" do
      apps = GraphDiscovery.discover_apps("/tmp/does-not-exist-#{System.unique_integer()}")
      assert apps == []
    end
  end

  describe "build_graph/1" do
    test "builds a valid graph from the real umbrella" do
      assert {:ok, graph} = GraphDiscovery.build_graph(@umbrella_root)
      assert %DependencyGraph{} = graph
    end

    test "discovered graph has all 19 apps" do
      {:ok, graph} = GraphDiscovery.build_graph(@umbrella_root)
      assert MapSet.size(DependencyGraph.all_apps(graph)) == 19
    end

    test "identity depends on perme8_events and perme8_plugs" do
      {:ok, graph} = GraphDiscovery.build_graph(@umbrella_root)
      deps = DependencyGraph.dependencies(graph, :identity)

      assert :perme8_events in deps
      assert :perme8_plugs in deps
    end

    test "perme8_tools has no in_umbrella deps" do
      {:ok, graph} = GraphDiscovery.build_graph(@umbrella_root)
      deps = DependencyGraph.dependencies(graph, :perme8_tools)

      assert MapSet.size(deps) == 0
    end

    test "alkali has no in_umbrella deps" do
      {:ok, graph} = GraphDiscovery.build_graph(@umbrella_root)
      deps = DependencyGraph.dependencies(graph, :alkali)

      assert MapSet.size(deps) == 0
    end

    test "jarga_web depends on jarga, agents, chat, chat_web" do
      {:ok, graph} = GraphDiscovery.build_graph(@umbrella_root)
      deps = DependencyGraph.dependencies(graph, :jarga_web)

      assert :jarga in deps
      assert :agents in deps
      assert :chat in deps
      assert :chat_web in deps
    end

    test "no circular dependencies in the real graph" do
      assert {:ok, _graph} = GraphDiscovery.build_graph(@umbrella_root)
    end

    test "chat_web excludes test-only deps" do
      {:ok, graph} = GraphDiscovery.build_graph(@umbrella_root)
      deps = DependencyGraph.dependencies(graph, :chat_web)

      # chat_web has {:jarga, in_umbrella: true, only: :test} -- should be excluded
      refute :jarga in deps
      # But includes runtime deps
      assert :chat in deps
      assert :identity in deps
      assert :agents in deps
    end
  end
end
