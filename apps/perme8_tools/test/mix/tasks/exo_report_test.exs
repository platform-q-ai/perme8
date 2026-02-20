defmodule Mix.Tasks.ExoReportTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.ExoReport

  describe "build_cmd_args/1" do
    test "builds base command args without results_dir" do
      args = ExoReport.build_cmd_args()

      assert args == [
               "run",
               "src/cli/index.ts",
               "serve"
             ]
    end

    test "builds base command args with nil results_dir" do
      args = ExoReport.build_cmd_args(nil)

      assert args == [
               "run",
               "src/cli/index.ts",
               "serve"
             ]
    end

    test "appends --results-dir when provided" do
      args = ExoReport.build_cmd_args("custom-results")

      assert args == [
               "run",
               "src/cli/index.ts",
               "serve",
               "--results-dir",
               "custom-results"
             ]
    end
  end
end
