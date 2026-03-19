defmodule Agents.Pipeline.Domain.Entities.GateTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.Gate

  describe "new/1" do
    test "creates a Gate struct" do
      gate = Gate.new(%{requires: ["build", "test"]})

      assert %Gate{} = gate
      assert gate.requires == ["build", "test"]
    end

    test "sets defaults" do
      gate = Gate.new(%{})

      assert gate.requires == []
      assert gate.evaluation == "all_of"
      assert gate.changes_in == []
    end

    test "accepts all fields" do
      gate =
        Gate.new(%{
          requires: ["build"],
          evaluation: "any_of",
          changes_in: ["apps/agents/**"]
        })

      assert gate.requires == ["build"]
      assert gate.evaluation == "any_of"
      assert gate.changes_in == ["apps/agents/**"]
    end
  end

  describe "empty?/1" do
    test "returns true when no requirements or changes_in" do
      gate = Gate.new(%{})

      assert Gate.empty?(gate) == true
    end

    test "returns false when requires is non-empty" do
      gate = Gate.new(%{requires: ["build"]})

      assert Gate.empty?(gate) == false
    end

    test "returns false when changes_in is non-empty" do
      gate = Gate.new(%{changes_in: ["apps/**"]})

      assert Gate.empty?(gate) == false
    end
  end

  describe "dependency_names/1" do
    test "returns the list of required stage names" do
      gate = Gate.new(%{requires: ["build", "test", "lint"]})

      assert Gate.dependency_names(gate) == ["build", "test", "lint"]
    end

    test "returns empty list when no dependencies" do
      gate = Gate.new(%{})

      assert Gate.dependency_names(gate) == []
    end
  end
end
