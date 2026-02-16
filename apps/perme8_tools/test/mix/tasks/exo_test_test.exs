defmodule Mix.Tasks.ExoTestTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.ExoTest

  describe "build_cmd_args/2" do
    test "builds base command args without tag" do
      args = ExoTest.build_cmd_args("/abs/path/config.ts", nil)

      assert args == [
               "run",
               "src/cli/index.ts",
               "run",
               "--config",
               "/abs/path/config.ts"
             ]
    end

    test "appends --tags when tag is provided" do
      args = ExoTest.build_cmd_args("/abs/path/config.ts", "@smoke")

      assert args == [
               "run",
               "src/cli/index.ts",
               "run",
               "--config",
               "/abs/path/config.ts",
               "--tags",
               "@smoke"
             ]
    end

    test "uses the absolute config path" do
      args = ExoTest.build_cmd_args("/home/user/project/config.ts", nil)

      assert Enum.at(args, 4) == "/home/user/project/config.ts"
    end

    test "passes complex tag expressions" do
      args = ExoTest.build_cmd_args("/abs/path/config.ts", "not @security and not @slow")

      assert args == [
               "run",
               "src/cli/index.ts",
               "run",
               "--config",
               "/abs/path/config.ts",
               "--tags",
               "not @security and not @slow"
             ]
    end
  end

  describe "config_name/1" do
    test "extracts stem from standard config path" do
      assert ExoTest.config_name("apps/jarga_web/test/exo-bdd-jarga-web.config.ts") ==
               "jarga-web"
    end

    test "extracts stem from long config name" do
      assert ExoTest.config_name(
               "apps/entity_relationship_manager/test/exo-bdd-entity-relationship-manager.config.ts"
             ) == "entity-relationship-manager"
    end

    test "handles bare filename" do
      assert ExoTest.config_name("exo-bdd-alkali.config.ts") == "alkali"
    end
  end

  describe "filter_configs/2" do
    @all_configs [
      "apps/alkali/test/exo-bdd-alkali.config.ts",
      "apps/entity_relationship_manager/test/exo-bdd-entity-relationship-manager.config.ts",
      "apps/identity/test/exo-bdd-identity.config.ts",
      "apps/jarga_api/test/exo-bdd-jarga-api.config.ts",
      "apps/jarga_web/test/exo-bdd-jarga-web.config.ts"
    ]

    test "returns all configs when name is nil" do
      assert ExoTest.filter_configs(@all_configs, nil) == @all_configs
    end

    test "exact match on config stem returns only that config" do
      assert ExoTest.filter_configs(@all_configs, "jarga-web") == [
               "apps/jarga_web/test/exo-bdd-jarga-web.config.ts"
             ]
    end

    test "exact match on jarga-api returns only jarga-api" do
      assert ExoTest.filter_configs(@all_configs, "jarga-api") == [
               "apps/jarga_api/test/exo-bdd-jarga-api.config.ts"
             ]
    end

    test "substring match returns multiple configs when no exact match" do
      result = ExoTest.filter_configs(@all_configs, "jarga")

      assert result == [
               "apps/jarga_api/test/exo-bdd-jarga-api.config.ts",
               "apps/jarga_web/test/exo-bdd-jarga-web.config.ts"
             ]
    end

    test "substring match works for partial names" do
      assert ExoTest.filter_configs(@all_configs, "relationship") == [
               "apps/entity_relationship_manager/test/exo-bdd-entity-relationship-manager.config.ts"
             ]
    end

    test "is case-insensitive for exact match" do
      assert ExoTest.filter_configs(@all_configs, "Jarga-Web") == [
               "apps/jarga_web/test/exo-bdd-jarga-web.config.ts"
             ]
    end

    test "is case-insensitive for substring match" do
      result = ExoTest.filter_configs(@all_configs, "JARGA")

      assert result == [
               "apps/jarga_api/test/exo-bdd-jarga-api.config.ts",
               "apps/jarga_web/test/exo-bdd-jarga-web.config.ts"
             ]
    end

    test "returns empty list when no match" do
      assert ExoTest.filter_configs(@all_configs, "nonexistent") == []
    end

    test "exact match takes priority over substring" do
      configs = [
        "apps/foo/test/exo-bdd-alkali.config.ts",
        "apps/bar/test/exo-bdd-alkali-extended.config.ts"
      ]

      # "alkali" is an exact match for the first config stem, so only it is returned
      assert ExoTest.filter_configs(configs, "alkali") == [
               "apps/foo/test/exo-bdd-alkali.config.ts"
             ]
    end
  end

  describe "run/1" do
    @tag :tmp_dir
    test "raises when --config points to a non-existent file and bun is available", %{
      tmp_dir: _
    } do
      if System.find_executable("bun") do
        assert_raise Mix.Error, fn ->
          ExoTest.run(["--config", "/tmp/does-not-exist-exo-bdd.config.ts"])
        end
      end
    end

    test "gracefully skips when bun is not available" do
      unless System.find_executable("bun") do
        assert ExoTest.run([]) == :ok
      end
    end
  end
end
