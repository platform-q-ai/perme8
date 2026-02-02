defmodule Credo.Check.Custom.Architecture.UseCaseConsistentInjection do
  @moduledoc """
  Detects when use cases call infrastructure modules directly instead of using
  the consistently injected dependency from opts.

  ## Clean Architecture Principle

  Use cases should receive ALL infrastructure dependencies via the opts parameter
  and use them consistently throughout the module. Direct calls to infrastructure
  modules (even with defaults) inside private functions violate this pattern.

  ## Why This Matters

  1. **Consistency**: All infrastructure access should follow the same pattern
  2. **Testability**: Tests can inject mocks for all dependencies
  3. **Visibility**: Easy to see all infrastructure dependencies in execute/2

  ## Examples

  ### Invalid - Mixed injection patterns:

      defmodule MyApp.Application.UseCases.BuildSite do
        def execute(site_path, opts \\\\ []) do
          file_system = Keyword.get(opts, :file_system, MyApp.Infrastructure.FileSystem)
          # Good: uses file_system from opts

          cache = load_cache(site_path)  # Bad: doesn't pass opts
        end

        defp load_cache(site_path) do
          # VIOLATION: Direct infrastructure call, not from opts
          MyApp.Infrastructure.BuildCache.load(site_path)
        end
      end

  ### Valid - Consistent injection:

      defmodule MyApp.Application.UseCases.BuildSite do
        def execute(site_path, opts \\\\ []) do
          file_system = Keyword.get(opts, :file_system, MyApp.Infrastructure.FileSystem)
          build_cache = Keyword.get(opts, :build_cache, MyApp.Infrastructure.BuildCache)

          cache = load_cache(site_path, build_cache)
        end

        defp load_cache(site_path, build_cache) do
          build_cache.load(site_path)  # Uses injected dependency
        end
      end

  ### Valid - Default function pattern (dependency injection with defaults):

      defmodule MyApp.Application.UseCases.BuildSite do
        def execute(site_path, opts \\\\ []) do
          file_system = Keyword.get(opts, :file_system, default_file_system())
          # ...
        end

        # This pattern is VALID - it provides injectable defaults
        defp default_file_system, do: MyApp.Infrastructure.FileSystem
      end

  The `default_*` function pattern is a valid DI approach because:
  1. It centralizes default infrastructure references
  2. Tests can override via opts: `execute(path, file_system: MockFileSystem)`
  3. The infrastructure module is returned, not called directly

  ## Configuration

  - `:infrastructure_patterns` - Patterns identifying infrastructure modules
  """

  use Credo.Check,
    id: "EX8012",
    base_priority: :high,
    category: :design,
    exit_status: 2,
    param_defaults: [
      infrastructure_patterns: ["Infrastructure", "Infra"]
    ],
    explanations: [
      check: """
      Use cases should access infrastructure consistently via opts injection.

      All infrastructure dependencies should be:
      1. Extracted from opts in execute/2 with defaults
      2. Passed to private functions that need them
      3. Never called directly from private functions

      This ensures:
      - All dependencies are visible in one place
      - Tests can easily mock any dependency
      - Consistent architectural pattern throughout

      Fix by:
      1. Add missing dependencies to execute/2 opts extraction
      2. Pass dependencies to private functions
      3. Use the passed dependency instead of direct calls
      """,
      params: [
        infrastructure_patterns: "Module name patterns that identify infrastructure layer."
      ]
    ]

  alias Credo.SourceFile
  alias Credo.IssueMeta
  alias Credo.Check.Params

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    infrastructure_patterns = Params.get(params, :infrastructure_patterns, __MODULE__)

    if use_case_file?(source_file) do
      check_direct_infrastructure_calls(source_file, issue_meta, infrastructure_patterns)
    else
      []
    end
  end

  defp use_case_file?(source_file) do
    filename = source_file.filename

    (String.contains?(filename, "/application/use_cases/") or
       String.contains?(filename, "/Application/UseCases/")) and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
  end

  defp check_direct_infrastructure_calls(source_file, issue_meta, infrastructure_patterns) do
    # Find direct infrastructure module calls in private functions
    # We look for patterns like: ModuleName.function() where ModuleName contains Infrastructure

    source = SourceFile.source(source_file)
    lines = String.split(source, "\n")

    # Track which functions are in defp (private) context
    # and find direct infrastructure calls there
    find_direct_calls_in_private_functions(lines, issue_meta, infrastructure_patterns)
  end

  defp find_direct_calls_in_private_functions(lines, issue_meta, infrastructure_patterns) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce({:public, false, []}, fn {line, line_no}, {context, in_default_fn, issues} ->
      cond do
        # Entering a public function
        String.match?(line, ~r/^\s*def\s+\w+/) and not String.match?(line, ~r/^\s*defp\s+/) ->
          {:public, false, issues}

        # Entering a default_* private function - these are valid DI patterns
        String.match?(line, ~r/^\s*defp\s+default_\w+/) ->
          {:private, true, issues}

        # Entering any other private function
        String.match?(line, ~r/^\s*defp\s+\w+/) ->
          {:private, false, issues}

        # In private context but inside a default_* function - skip checking
        context == :private and in_default_fn ->
          {:private, in_default_fn, issues}

        # In private context, check for direct infrastructure calls
        context == :private ->
          new_issues =
            check_line_for_infrastructure(line, line_no, issue_meta, infrastructure_patterns)

          {:private, in_default_fn, new_issues ++ issues}

        true ->
          {context, in_default_fn, issues}
      end
    end)
    |> elem(2)
  end

  defp check_line_for_infrastructure(line, line_no, issue_meta, patterns) do
    # Look for patterns like: Infrastructure.Module.function(
    # or Alkali.Infrastructure.BuildCache.load(
    Enum.flat_map(patterns, fn pattern ->
      regex = ~r/([A-Z][\w.]*#{pattern}[\w.]*)\.\w+\(/

      case Regex.run(regex, line) do
        [_, module_name] ->
          # Skip if this is in a Keyword.get default (acceptable pattern)
          if String.contains?(line, "Keyword.get") do
            []
          else
            [
              format_issue(
                issue_meta,
                message:
                  "Direct infrastructure call to `#{module_name}` in private function. " <>
                    "Extract this dependency via opts in execute/2 and pass it to private functions. " <>
                    "Example: build_cache = Keyword.get(opts, :build_cache, #{module_name})",
                trigger: module_name,
                line_no: line_no
              )
            ]
          end

        _ ->
          []
      end
    end)
  end
end
