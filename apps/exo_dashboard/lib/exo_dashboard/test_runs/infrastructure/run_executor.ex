defmodule ExoDashboard.TestRuns.Infrastructure.RunExecutor do
  @moduledoc """
  Spawns test run processes using bun/exo-bdd.

  Builds the correct CLI arguments for the given scope and
  spawns a Task that runs the test suite.
  """

  @ndjson_dir "/tmp/exo_dashboard"

  @doc """
  Starts a test run for the given run_id and scope.

  Spawns a Task that runs `bun run exo-bdd` with appropriate arguments.
  Returns `{:ok, pid}`.
  """
  @spec start(String.t(), keyword()) :: {:ok, pid()}
  def start(run_id, opts \\ []) do
    args = build_args(run_id, opts)
    exo_bdd_root = Keyword.get(opts, :exo_bdd_root, find_exo_bdd_root())

    task =
      Task.async(fn ->
        File.mkdir_p!(@ndjson_dir)

        System.cmd("bun", ["run", "exo-bdd" | args],
          cd: exo_bdd_root,
          stderr_to_stdout: true
        )
      end)

    {:ok, task.pid}
  end

  @doc """
  Builds the CLI arguments for a test run.

  The `--format message:<path>` argument enables NDJSON output
  which is consumed by the NdjsonWatcher.
  """
  @spec build_args(String.t(), keyword()) :: [String.t()]
  def build_args(run_id, opts \\ []) do
    scope = Keyword.get(opts, :scope, {:app, "all"})
    ndjson_path = ndjson_path(run_id)

    base_args = ["--format", "message:#{ndjson_path}"]

    scope_args =
      case scope do
        {:app, app_name} ->
          ["--tags", "@#{app_name}"]

        {:feature, uri} ->
          [uri]

        {:scenario, uri, line} ->
          ["#{uri}:#{line}"]

        _ ->
          []
      end

    base_args ++ scope_args
  end

  @doc "Returns the NDJSON output path for a given run_id."
  @spec ndjson_path(String.t()) :: String.t()
  def ndjson_path(run_id) do
    Path.join(@ndjson_dir, "#{run_id}.ndjson")
  end

  defp find_exo_bdd_root do
    Application.app_dir(:exo_dashboard)
    |> Path.join("../../..")
    |> Path.expand()
  end
end
