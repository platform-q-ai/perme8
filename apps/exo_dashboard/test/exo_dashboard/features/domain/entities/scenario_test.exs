defmodule ExoDashboard.Features.Domain.Entities.ScenarioTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.Features.Domain.Entities.Scenario

  describe "new/1" do
    test "creates a scenario with all fields" do
      scenario =
        Scenario.new(
          id: "sc-1",
          name: "User logs in successfully",
          keyword: "Scenario",
          description: "Happy path login",
          tags: ["@smoke", "@login"],
          steps: [:step_placeholder],
          examples: [:example_placeholder],
          location: %{line: 5, column: 3}
        )

      assert scenario.id == "sc-1"
      assert scenario.name == "User logs in successfully"
      assert scenario.keyword == "Scenario"
      assert scenario.description == "Happy path login"
      assert scenario.tags == ["@smoke", "@login"]
      assert scenario.steps == [:step_placeholder]
      assert scenario.examples == [:example_placeholder]
      assert scenario.location == %{line: 5, column: 3}
    end

    test "defaults steps to empty list" do
      scenario = Scenario.new(name: "Minimal")
      assert scenario.steps == []
    end

    test "defaults tags to empty list" do
      scenario = Scenario.new(name: "No Tags")
      assert scenario.tags == []
    end

    test "creates from map" do
      scenario = Scenario.new(%{name: "From Map", keyword: "Scenario Outline"})
      assert scenario.name == "From Map"
      assert scenario.keyword == "Scenario Outline"
    end
  end
end
