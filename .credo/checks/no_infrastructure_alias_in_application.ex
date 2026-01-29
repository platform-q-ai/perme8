defmodule Credo.Check.Custom.Architecture.NoInfrastructureAliasInApplication do
  @moduledoc """
  Detects when application layer modules alias infrastructure modules directly.

  ## Clean Architecture Violation

  Application layer (use cases) should depend on abstractions (behaviours), not
  concrete infrastructure implementations. Direct aliasing creates tight coupling.

  ## Examples

  ### Invalid - Direct infrastructure alias in use case:

      # lib/my_app/application/use_cases/build_site.ex
      defmodule MyApp.Application.UseCases.BuildSite do
        alias MyApp.Infrastructure.FileSystem  # VIOLATION

        def execute(opts) do
          FileSystem.read(path)  # Tight coupling
        end
      end

  ### Valid - Use behaviour and dependency injection:

      # lib/my_app/application/use_cases/build_site.ex
      defmodule MyApp.Application.UseCases.BuildSite do
        # No infrastructure alias!

        def execute(opts) do
          file_system = Keyword.get(opts, :file_system, default_file_system())
          file_system.read(path)  # Injected dependency
        end

        defp default_file_system do
          Application.get_env(:my_app, :file_system, MyApp.Infrastructure.FileSystem)
        end
      end

  ## Configuration

  - `:infrastructure_patterns` - Patterns that identify infrastructure modules
    Default: ["Infrastructure", "Infra"]
  - `:application_patterns` - Patterns that identify application layer modules
    Default: ["Application", "UseCases", "UseCase"]
  """

  use Credo.Check,
    id: "EX8001",
    base_priority: :high,
    category: :design,
    exit_status: 2,
    param_defaults: [
      infrastructure_patterns: ["Infrastructure", "Infra"],
      application_patterns: ["Application", "UseCases", "UseCase"]
    ],
    explanations: [
      check: """
      Application layer should not directly alias infrastructure modules.

      This violates the Dependency Inversion Principle:
      - High-level modules should not depend on low-level modules
      - Both should depend on abstractions

      Instead of aliasing infrastructure directly:
      1. Define a behaviour in the application layer
      2. Have infrastructure implement the behaviour
      3. Inject the dependency via opts or config

      Benefits:
      - Testable with mocks (no infrastructure needed)
      - Swappable implementations
      - Clear architectural boundaries
      """,
      params: [
        infrastructure_patterns: "Module name patterns that identify infrastructure layer.",
        application_patterns: "Module name patterns that identify application layer."
      ]
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta
  alias Credo.Check.Params

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    application_patterns = Params.get(params, :application_patterns, __MODULE__)

    if application_layer_file?(source_file, application_patterns) do
      infrastructure_patterns = Params.get(params, :infrastructure_patterns, __MODULE__)
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta, infrastructure_patterns))
    else
      []
    end
  end

  defp application_layer_file?(source_file, patterns) do
    path = source_file.filename |> String.downcase()

    # Must be in lib/, not in test/
    # Must match one of the application patterns (case-insensitive)
    String.contains?(path, "/lib/") and
      not String.contains?(path, "/test/") and
      Enum.any?(patterns, fn pattern ->
        String.contains?(path, String.downcase(pattern))
      end)
  end

  # Detect `alias Some.Infrastructure.Module`
  defp traverse(
         {:alias, meta, [{:__aliases__, _, module_parts}]} = ast,
         issues,
         issue_meta,
         infrastructure_patterns
       ) do
    module_string = Enum.join(module_parts, ".")

    if infrastructure_module?(module_string, infrastructure_patterns) do
      issue = issue_for(issue_meta, meta, module_string, :alias)
      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  # Detect `alias Some.Infrastructure.{ModuleA, ModuleB}`
  defp traverse(
         {:alias, meta, [{{:., _, [{:__aliases__, _, base_parts}, :{}]}, _, nested}]} = ast,
         issues,
         issue_meta,
         infrastructure_patterns
       ) do
    base_module = Enum.join(base_parts, ".")

    new_issues =
      if infrastructure_module?(base_module, infrastructure_patterns) do
        nested
        |> Enum.map(fn {:__aliases__, _, parts} ->
          full_module = base_module <> "." <> Enum.join(parts, ".")
          issue_for(issue_meta, meta, full_module, :alias)
        end)
      else
        []
      end

    {ast, new_issues ++ issues}
  end

  # NOTE: We intentionally DO NOT check direct module calls in function bodies.
  # Direct calls inside private `default_*` functions are acceptable because:
  # 1. The main execute() function uses dependency injection via opts
  # 2. default_* functions only run when no mock is injected  
  # 3. Testability is already ensured via the opts parameter
  # 
  # What we DO check is top-level `alias` statements, which make infrastructure
  # available throughout the entire module and encourage direct usage.

  defp traverse(ast, issues, _issue_meta, _infrastructure_patterns) do
    {ast, issues}
  end

  defp infrastructure_module?(module_string, patterns) do
    Enum.any?(patterns, &String.contains?(module_string, &1))
  end

  defp issue_for(issue_meta, meta, module_string, type) do
    action = if type == :alias, do: "aliases", else: "directly calls"

    format_issue(
      issue_meta,
      message:
        "Application layer #{action} infrastructure module `#{module_string}`. " <>
          "Use dependency injection instead: define a behaviour, inject via opts, " <>
          "and resolve defaults through Application config. " <>
          "This ensures testability and follows Clean Architecture.",
      trigger: module_string,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
