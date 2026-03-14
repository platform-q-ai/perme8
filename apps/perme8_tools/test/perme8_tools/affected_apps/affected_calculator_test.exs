defmodule Perme8Tools.AffectedApps.AffectedCalculatorTest do
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.{AffectedCalculator, DependencyGraph}

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

  setup do
    {:ok, graph} = DependencyGraph.build(@perme8_deps)
    %{graph: graph}
  end

  describe "calculate/2" do
    test "identity change includes all transitive dependents", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new([:identity]),
        all_apps?: false,
        all_exo_bdd?: false
      }

      result = AffectedCalculator.calculate(classification, graph)

      assert :identity in result.affected_apps
      assert :agents in result.affected_apps
      assert :notifications in result.affected_apps
      assert :chat in result.affected_apps
      assert :jarga in result.affected_apps
      assert :jarga_web in result.affected_apps
      assert :jarga_api in result.affected_apps
      assert :agents_web in result.affected_apps
      assert :agents_api in result.affected_apps
      assert :chat_web in result.affected_apps
      assert :webhooks in result.affected_apps
      assert :webhooks_api in result.affected_apps
      assert :entity_relationship_manager in result.affected_apps
      assert :perme8_dashboard in result.affected_apps

      # Independent apps not affected
      refute :alkali in result.affected_apps
      refute :perme8_tools in result.affected_apps
      refute :exo_dashboard in result.affected_apps
    end

    test "alkali change only affects alkali", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new([:alkali]),
        all_apps?: false,
        all_exo_bdd?: false
      }

      result = AffectedCalculator.calculate(classification, graph)

      assert result.affected_apps == MapSet.new([:alkali])
    end

    test "perme8_events change propagates to most apps", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new([:perme8_events]),
        all_apps?: false,
        all_exo_bdd?: false
      }

      result = AffectedCalculator.calculate(classification, graph)

      # perme8_events is foundational - most apps depend on it
      assert :perme8_events in result.affected_apps
      assert :identity in result.affected_apps
      assert :agents in result.affected_apps
      assert :jarga in result.affected_apps
      assert :chat in result.affected_apps
      assert :notifications in result.affected_apps
      assert :jarga_web in result.affected_apps

      # Independent apps not affected
      refute :alkali in result.affected_apps
      refute :perme8_tools in result.affected_apps
      refute :exo_dashboard in result.affected_apps
      # perme8_plugs does NOT depend on perme8_events
      refute :perme8_plugs in result.affected_apps
    end

    test "shared config triggers all apps", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new(),
        all_apps?: true,
        all_exo_bdd?: false
      }

      result = AffectedCalculator.calculate(classification, graph)

      assert result.all_apps? == true
      assert MapSet.size(result.affected_apps) == 19
    end

    test "empty file list returns empty affected set", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new(),
        all_apps?: false,
        all_exo_bdd?: false
      }

      result = AffectedCalculator.calculate(classification, graph)

      assert result.affected_apps == MapSet.new()
    end

    test "tools/exo-bdd change sets all_exo_bdd flag without unit test apps", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new(),
        all_apps?: false,
        all_exo_bdd?: true
      }

      result = AffectedCalculator.calculate(classification, graph)

      assert result.all_exo_bdd? == true
      assert result.affected_apps == MapSet.new()
    end

    test "multiple files across apps unions affected sets", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new([:identity, :alkali]),
        all_apps?: false,
        all_exo_bdd?: false
      }

      result = AffectedCalculator.calculate(classification, graph)

      # identity dependents
      assert :agents in result.affected_apps
      assert :jarga in result.affected_apps
      # alkali itself
      assert :alkali in result.affected_apps
      # both directly affected
      assert :identity in result.affected_apps
    end

    test "jarga_web change does not propagate back (leaf app)", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new([:jarga_web]),
        all_apps?: false,
        all_exo_bdd?: false
      }

      result = AffectedCalculator.calculate(classification, graph)

      # jarga_web is a leaf - nothing depends on it
      assert result.affected_apps == MapSet.new([:jarga_web])
    end

    test "carries through all_exo_bdd flag with app changes", %{graph: graph} do
      classification = %{
        directly_affected: MapSet.new([:identity]),
        all_apps?: false,
        all_exo_bdd?: true
      }

      result = AffectedCalculator.calculate(classification, graph)

      assert result.all_exo_bdd? == true
      assert :identity in result.affected_apps
      assert :agents in result.affected_apps
    end
  end
end
