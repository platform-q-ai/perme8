defmodule ExoDashboard.Integration.FullFlowTest do
  @moduledoc """
  Integration tests for the full feature discovery flow.

  These tests use real .feature files from the umbrella project
  and the actual Gherkin parser to verify end-to-end feature discovery.
  """
  use ExUnit.Case, async: false

  alias ExoDashboard.Features
  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario, Step, Rule}
  alias ExoDashboard.Features.Infrastructure.{FeatureFileScanner, GherkinParser}

  # __DIR__ = apps/exo_dashboard/test/exo_dashboard/integration/
  # Up 5 levels to reach the umbrella root
  @umbrella_root Path.expand("../../../../..", __DIR__)

  # A scanner module that uses the correct umbrella root
  defmodule UmbrellaScanner do
    @umbrella_root Path.expand("../../../../..", __DIR__)

    def scan do
      ExoDashboard.Features.Infrastructure.FeatureFileScanner.scan(@umbrella_root)
    end
  end

  describe "feature discovery flow" do
    test "discovers features from real .feature files in umbrella" do
      {:ok, catalog} =
        Features.discover(scanner: UmbrellaScanner, parser: GherkinParser)

      # There should be at least one app with feature files
      assert map_size(catalog.apps) > 0, "Expected at least one app with features"

      # Each app should have features
      for {app_name, features} <- catalog.apps do
        assert is_binary(app_name), "App name should be a string"
        assert features != [], "App #{app_name} should have at least one feature"

        for feature <- features do
          assert %Feature{} = feature
          assert is_binary(feature.name), "Feature should have a name"
          assert is_binary(feature.uri), "Feature should have a URI"
          assert is_binary(feature.app), "Feature should have an app"
          assert feature.adapter in [:browser, :http, :security, :cli, :graph, :unknown]
        end
      end
    end

    test "discovered features have correct adapter classification" do
      {:ok, catalog} =
        Features.discover(scanner: UmbrellaScanner, parser: GherkinParser)

      # by_adapter should group features by known adapter types
      for {adapter, features} <- catalog.by_adapter do
        assert adapter in [:browser, :http, :security, :cli, :graph],
               "Adapter should be a known type, got: #{inspect(adapter)}"

        for feature <- features do
          assert feature.adapter == adapter,
                 "Feature #{feature.name} should have adapter #{adapter}"
        end
      end
    end

    test "parse a known .feature file and verify structure" do
      features = FeatureFileScanner.scan(@umbrella_root)
      assert features != [], "Should find at least one feature file"

      # Pick a .cli.feature file that we know exists
      feature_path = Enum.find(features, &String.ends_with?(&1, ".cli.feature"))

      assert feature_path != nil,
             "Should find at least one .cli.feature file"

      {:ok, feature} = GherkinParser.parse(feature_path)

      assert %Feature{} = feature
      assert is_binary(feature.name)
      assert feature.name != ""
      assert is_list(feature.children)

      # Each child should be a Scenario or Rule
      for child <- feature.children do
        assert match?(%Scenario{}, child) or match?(%Rule{}, child),
               "Feature child should be a Scenario or Rule, got: #{inspect(child.__struct__)}"
      end
    end

    test "parse a feature with scenarios containing steps" do
      features = FeatureFileScanner.scan(@umbrella_root)
      feature_path = List.first(features)

      assert feature_path != nil, "Should find at least one feature file"

      {:ok, feature} = GherkinParser.parse(feature_path)

      # Find scenarios (either direct children or inside rules)
      scenarios = extract_all_scenarios(feature.children)
      assert scenarios != [], "Feature should have at least one scenario"

      for scenario <- scenarios do
        assert %Scenario{} = scenario
        assert is_binary(scenario.name)
        assert is_list(scenario.steps)

        for step <- scenario.steps do
          assert %Step{} = step
          assert is_binary(step.keyword)
          assert is_binary(step.text)
        end
      end
    end

    test "gherkin parser handles all feature files without errors" do
      features = FeatureFileScanner.scan(@umbrella_root)
      assert features != [], "Should find at least one feature file"

      results =
        Enum.map(features, fn path ->
          {path, GherkinParser.parse(path)}
        end)

      errors =
        Enum.filter(results, fn
          {_path, {:error, _}} -> true
          _ -> false
        end)

      assert errors == [],
             "All feature files should parse successfully, but these failed:\n" <>
               Enum.map_join(errors, "\n", fn {path, {:error, reason}} ->
                 "  #{path}: #{inspect(reason)}"
               end)
    end
  end

  # Helper to extract all scenarios from children (including inside rules)
  defp extract_all_scenarios(children) do
    Enum.flat_map(children, fn
      %Scenario{} = scenario -> [scenario]
      %Rule{children: rule_children} -> extract_all_scenarios(rule_children)
      _ -> []
    end)
  end
end
