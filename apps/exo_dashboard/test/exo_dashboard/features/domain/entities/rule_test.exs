defmodule ExoDashboard.Features.Domain.Entities.RuleTest do
  use ExUnit.Case, async: true

  alias ExoDashboard.Features.Domain.Entities.Rule

  describe "new/1" do
    test "creates a rule with all fields" do
      rule =
        Rule.new(
          id: "rule-1",
          name: "Admin privileges",
          description: "Admins can do admin things",
          tags: ["@admin"],
          children: [:scenario_placeholder]
        )

      assert rule.id == "rule-1"
      assert rule.name == "Admin privileges"
      assert rule.description == "Admins can do admin things"
      assert rule.tags == ["@admin"]
      assert rule.children == [:scenario_placeholder]
    end

    test "defaults children to empty list" do
      rule = Rule.new(name: "Empty Rule")
      assert rule.children == []
    end

    test "defaults tags to empty list" do
      rule = Rule.new(name: "No Tags")
      assert rule.tags == []
    end

    test "creates from map" do
      rule = Rule.new(%{name: "Map Rule", description: "From map"})
      assert rule.name == "Map Rule"
      assert rule.description == "From map"
    end
  end
end
