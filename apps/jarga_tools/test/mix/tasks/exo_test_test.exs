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

  describe "filter_configs/2" do
    test "returns all configs when name is nil" do
      configs = ["apps/foo/test/exo-bdd-foo.config.ts", "apps/bar/test/exo-bdd-bar.config.ts"]
      assert ExoTest.filter_configs(configs, nil) == configs
    end

    test "filters configs by app name substring" do
      configs = [
        "apps/entity_relationship_manager/test/exo-bdd-entity-relationship-manager.config.ts",
        "apps/jarga_api/test/exo-bdd-jarga-api.config.ts"
      ]

      assert ExoTest.filter_configs(configs, "entity") == [
               "apps/entity_relationship_manager/test/exo-bdd-entity-relationship-manager.config.ts"
             ]
    end

    test "filters by exact config file name" do
      configs = [
        "apps/entity_relationship_manager/test/exo-bdd-entity-relationship-manager.config.ts",
        "apps/jarga_api/test/exo-bdd-jarga-api.config.ts"
      ]

      assert ExoTest.filter_configs(configs, "jarga-api") == [
               "apps/jarga_api/test/exo-bdd-jarga-api.config.ts"
             ]
    end

    test "is case-insensitive" do
      configs = ["apps/jarga_api/test/exo-bdd-jarga-api.config.ts"]
      assert ExoTest.filter_configs(configs, "Jarga") == configs
    end

    test "returns empty list when no match" do
      configs = ["apps/foo/test/exo-bdd-foo.config.ts"]
      assert ExoTest.filter_configs(configs, "nonexistent") == []
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
