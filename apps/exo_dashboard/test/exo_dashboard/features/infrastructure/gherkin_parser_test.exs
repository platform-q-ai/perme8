defmodule ExoDashboard.Features.Infrastructure.GherkinParserTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.Features.Infrastructure.GherkinParser
  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario, Step, Rule}

  @fixtures_dir Path.expand("../../../support/fixtures", __DIR__)

  # These tests require bun + @cucumber/gherkin installed; tag as :external
  # so they can be excluded from CI or fast test runs.
  # TODO: Add fixture-based unit tests for parse_output/2 and transform_document/2
  # that don't require the bun runtime.

  describe "parse/1 with simple feature" do
    @tag :external
    test "returns {:ok, %Feature{}} with correct name" do
      path = Path.join(@fixtures_dir, "simple.feature")
      assert {:ok, %Feature{} = feature} = GherkinParser.parse(path)
      assert feature.name == "Simple Login"
      assert feature.uri == path
    end

    @tag :external
    test "extracts scenarios with steps" do
      path = Path.join(@fixtures_dir, "simple.feature")
      {:ok, feature} = GherkinParser.parse(path)

      assert length(feature.children) == 1
      [scenario] = feature.children
      assert %Scenario{} = scenario
      assert scenario.name == "Successful login"
      assert length(scenario.steps) == 3

      [given, when_step, then_step] = scenario.steps
      assert %Step{} = given
      assert given.keyword =~ "Given"
      assert given.text == "I am on the login page"
      assert %Step{} = when_step
      assert when_step.text == "I enter valid credentials"
      assert %Step{} = then_step
      assert then_step.text == "I should be logged in"
    end
  end

  describe "parse/1 with complex feature" do
    @tag :external
    test "extracts feature-level tags" do
      path = Path.join(@fixtures_dir, "complex.feature")
      {:ok, feature} = GherkinParser.parse(path)

      assert "@authentication" in feature.tags
    end

    @tag :external
    test "extracts rules with nested scenarios" do
      path = Path.join(@fixtures_dir, "complex.feature")
      {:ok, feature} = GherkinParser.parse(path)

      rules = Enum.filter(feature.children, &match?(%Rule{}, &1))
      assert length(rules) == 1

      [rule] = rules
      assert rule.name == "Password Requirements"
      assert length(rule.children) >= 2
    end

    @tag :external
    test "extracts scenario outlines (nested in rules)" do
      path = Path.join(@fixtures_dir, "complex.feature")
      {:ok, feature} = GherkinParser.parse(path)

      # The Scenario Outline is nested inside the Rule
      rules = Enum.filter(feature.children, &match?(%Rule{}, &1))
      [rule] = rules

      outlines =
        Enum.filter(rule.children, fn
          %Scenario{keyword: keyword} -> keyword =~ "Outline"
          _ -> false
        end)

      assert length(outlines) == 1
      [outline] = outlines
      assert outline.name == "Login with different roles"
      assert is_list(outline.examples)
      assert outline.examples != []
    end
  end

  describe "parse/1 with non-existent file" do
    test "returns {:error, reason}" do
      result = GherkinParser.parse("/nonexistent/path/does_not_exist.feature")
      assert {:error, reason} = result
      assert is_binary(reason)
    end
  end
end
