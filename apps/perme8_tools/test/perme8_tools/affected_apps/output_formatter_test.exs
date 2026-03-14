defmodule Perme8Tools.AffectedApps.OutputFormatterTest do
  use ExUnit.Case, async: true

  alias Perme8Tools.AffectedApps.OutputFormatter

  @base_result %{
    affected_apps: MapSet.new([:identity, :agents]),
    all_apps?: false,
    all_exo_bdd?: false,
    unit_test_paths: ["apps/agents/test", "apps/identity/test"],
    mix_test_command: "mix test apps/agents/test apps/identity/test",
    exo_bdd_combos: [
      %{app: "identity", domain: "browser", config_name: "identity", timeout: 15},
      %{app: "identity", domain: "security", config_name: "identity", timeout: 20}
    ]
  }

  describe "format_json/1" do
    test "produces valid JSON" do
      json = OutputFormatter.format_json(@base_result)
      assert {:ok, _} = Jason.decode(json)
    end

    test "includes all expected keys" do
      json = OutputFormatter.format_json(@base_result)
      {:ok, decoded} = Jason.decode(json)

      assert Map.has_key?(decoded, "affected_apps")
      assert Map.has_key?(decoded, "unit_test_paths")
      assert Map.has_key?(decoded, "exo_bdd_combos")
      assert Map.has_key?(decoded, "all_apps")
      assert Map.has_key?(decoded, "all_exo_bdd")
    end

    test "sorts affected apps alphabetically" do
      json = OutputFormatter.format_json(@base_result)
      {:ok, decoded} = Jason.decode(json)

      assert decoded["affected_apps"] == ["agents", "identity"]
    end

    test "affected apps are strings, not atoms" do
      json = OutputFormatter.format_json(@base_result)
      {:ok, decoded} = Jason.decode(json)

      for app <- decoded["affected_apps"] do
        assert is_binary(app)
      end
    end

    test "exo_bdd_combos match CI matrix format" do
      json = OutputFormatter.format_json(@base_result)
      {:ok, decoded} = Jason.decode(json)

      for combo <- decoded["exo_bdd_combos"] do
        assert Map.has_key?(combo, "app")
        assert Map.has_key?(combo, "domain")
        assert Map.has_key?(combo, "config_name")
        assert Map.has_key?(combo, "timeout")
      end
    end

    test "includes unit test paths" do
      json = OutputFormatter.format_json(@base_result)
      {:ok, decoded} = Jason.decode(json)

      assert decoded["unit_test_paths"] == ["apps/agents/test", "apps/identity/test"]
    end

    test "includes mix_test_command" do
      json = OutputFormatter.format_json(@base_result)
      {:ok, decoded} = Jason.decode(json)

      assert decoded["mix_test_command"] == "mix test apps/agents/test apps/identity/test"
    end
  end

  describe "format_human/1" do
    test "shows affected apps count and names" do
      output = OutputFormatter.format_human(@base_result)
      assert output =~ "Affected apps (2)"
      assert output =~ "agents"
      assert output =~ "identity"
    end

    test "shows no apps affected for empty set" do
      result = %{
        @base_result
        | affected_apps: MapSet.new(),
          mix_test_command: nil,
          exo_bdd_combos: []
      }

      output = OutputFormatter.format_human(result)
      assert output =~ "No apps affected"
    end

    test "shows all apps affected for shared config" do
      result = %{@base_result | all_apps?: true}
      output = OutputFormatter.format_human(result)
      assert output =~ "ALL"
      assert output =~ "shared config"
    end

    test "shows unit test command" do
      output = OutputFormatter.format_human(@base_result)
      assert output =~ "mix test apps/agents/test apps/identity/test"
    end

    test "shows exo-bdd combos" do
      output = OutputFormatter.format_human(@base_result)
      assert output =~ "Exo-BDD combos (2)"
      assert output =~ "identity [browser]"
      assert output =~ "identity [security]"
    end
  end
end
