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
  end

  describe "run/1 argument parsing" do
    test "raises when --config is missing" do
      assert_raise Mix.Error, ~r/Missing required --config option/, fn ->
        ExoTest.run([])
      end
    end
  end
end
