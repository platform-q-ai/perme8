defmodule Mix.Tasks.StepLinter do
  @moduledoc """
  Lints Cucumber step definition files for common issues.

  This linter analyzes step definitions and reports issues that can cause
  tests to be flaky, invalid, or pass silently.

  ## Usage

      mix step_linter                           # Lint all step definitions
      mix step_linter --rule no_branching       # Run specific rule only
      mix step_linter path/to/file.exs          # Lint specific file

  ## Available Rules

  - `no_branching` - Detects if/case/cond statements that make steps context-dependent
  - `no_sleep_calls` - Detects Process.sleep/:timer.sleep calls (use wait_until instead)
  - `no_stubs` - Detects stub steps that only return context without real actions
  - `step_too_long` - Flags steps over 25 lines (extract helper functions)
  - `unused_context_parameter` - Detects unused context params (use _context instead)
  - `file_too_long` - Flags files over 300 lines (split into smaller logical groupings)
  - `use_liveview_testing` - Enforces LiveView testing instead of direct backend calls

  ## Adding New Rules

  Create a new module implementing the `Mix.Tasks.StepLinter.Rule` behaviour
  in `lib/mix/tasks/step_linter/rules/`. See `NoBranching` for an example.
  """
  use Boundary, top_level?: true
  use Mix.Task

  alias Mix.Tasks.StepLinter.{Parser, Reporter, RuleRunner}

  @shortdoc "Lints Cucumber step definitions for common issues"

  @default_path "apps/**/test/features/step_definitions"

  @impl Mix.Task
  def run(args) do
    {opts, paths, _} =
      OptionParser.parse(args,
        switches: [rule: :string, format: :string, fix: :boolean],
        aliases: [r: :rule, f: :format]
      )

    paths = if Enum.empty?(paths), do: [@default_path], else: paths
    selected_rule = Keyword.get(opts, :rule)
    format = Keyword.get(opts, :format, "text")

    files = gather_files(paths)

    if Enum.empty?(files) do
      Mix.shell().info("No step definition files found.")
      :ok
    else
      Mix.shell().info("Linting #{length(files)} step definition file(s)...\n")

      issues =
        files
        |> Enum.flat_map(&lint_file(&1, selected_rule))
        |> Enum.sort_by(&{&1.file, &1.line})

      Reporter.report(issues, format)

      if Enum.any?(issues, &(&1.severity == :error)) do
        Mix.raise("Step linter found #{length(issues)} issue(s)")
      else
        :ok
      end
    end
  end

  defp gather_files(paths) do
    paths
    |> Enum.flat_map(&expand_path/1)
    |> Enum.uniq()
  end

  defp expand_path(path) do
    cond do
      # Handle glob patterns (contain * or ?)
      String.contains?(path, ["*", "?"]) ->
        expand_glob_pattern(path)

      File.dir?(path) ->
        # Match all .exs files recursively
        Path.wildcard(Path.join(path, "**/*.exs"))

      File.exists?(path) ->
        [path]

      true ->
        Mix.shell().error("Path not found: #{path}")
        []
    end
  end

  defp expand_glob_pattern(pattern) do
    pattern
    |> Path.wildcard()
    |> Enum.flat_map(&files_in_directory/1)
  end

  defp files_in_directory(dir) do
    case File.dir?(dir) do
      true -> Path.wildcard(Path.join(dir, "**/*.exs"))
      false -> []
    end
  end

  defp lint_file(file, selected_rule) do
    file_line_count = count_file_lines(file)

    case Parser.parse_file(file) do
      {:ok, step_definitions} ->
        RuleRunner.run_rules(file, step_definitions, selected_rule,
          file_line_count: file_line_count
        )

      {:error, reason} ->
        [
          %{
            file: file,
            line: 0,
            rule: "parse_error",
            message: "Failed to parse file: #{inspect(reason)}",
            severity: :error
          }
        ]
    end
  end

  defp count_file_lines(file) do
    case File.read(file) do
      {:ok, content} ->
        content |> String.split("\n") |> length()

      {:error, _} ->
        0
    end
  end
end
