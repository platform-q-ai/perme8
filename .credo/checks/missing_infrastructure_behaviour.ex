defmodule Credo.Check.Custom.Architecture.MissingInfrastructureBehaviour do
  @moduledoc """
  Detects infrastructure modules that don't implement a corresponding behaviour.

  ## Clean Architecture Principle

  Infrastructure modules should implement behaviours defined in the application layer.
  This enables:
  - Dependency Inversion: Use cases depend on abstractions, not implementations
  - Testability: Can substitute mock implementations
  - Documentation: Behaviours clearly define the contract

  ## Examples

  ### Invalid - Infrastructure without behaviour:

      # lib/my_app/infrastructure/parsers/frontmatter_parser.ex
      defmodule MyApp.Infrastructure.Parsers.FrontmatterParser do
        # No @behaviour declaration!

        def parse(content) do
          # parsing logic
        end
      end

  ### Valid - Infrastructure implements behaviour:

      # lib/my_app/application/behaviours/frontmatter_parser_behaviour.ex
      defmodule MyApp.Application.Behaviours.FrontmatterParserBehaviour do
        @callback parse(String.t()) :: {:ok, {map(), String.t()}} | {:error, String.t()}
      end

      # lib/my_app/infrastructure/parsers/frontmatter_parser.ex
      defmodule MyApp.Infrastructure.Parsers.FrontmatterParser do
        @behaviour MyApp.Application.Behaviours.FrontmatterParserBehaviour

        @impl true
        def parse(content) do
          # parsing logic
        end
      end

  ## Configuration

  - `:excluded_modules` - Infrastructure modules that don't need behaviours
    (e.g., pure utility modules). Default: []
  - `:required_patterns` - Only check modules matching these patterns.
    Default: ["Parser", "Renderer", "Repository", "Service", "Resolver", "Cache"]
  """

  use Credo.Check,
    id: "EX8011",
    base_priority: :normal,
    category: :design,
    exit_status: 2,
    param_defaults: [
      excluded_modules: [],
      required_patterns: ["Parser", "Renderer", "Repository", "Service", "Resolver", "Cache"]
    ],
    explanations: [
      check: """
      Infrastructure modules with public APIs should implement behaviours.

      Benefits:
      - Dependency Inversion: Application layer depends on abstraction
      - Testability: Easy to mock in tests
      - Documentation: Clear contract definition
      - Substitutability: Can swap implementations

      Fix by:
      1. Create a behaviour in application/behaviours/
      2. Add @behaviour declaration to infrastructure module
      3. Mark public functions with @impl true
      """,
      params: [
        excluded_modules: "Module name patterns to skip checking.",
        required_patterns: "Only check modules matching these patterns."
      ]
    ]

  alias Credo.SourceFile
  alias Credo.IssueMeta
  alias Credo.Check.Params

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    excluded_modules = Params.get(params, :excluded_modules, __MODULE__)
    required_patterns = Params.get(params, :required_patterns, __MODULE__)

    if should_check?(source_file, excluded_modules, required_patterns) do
      check_for_behaviour(source_file, issue_meta)
    else
      []
    end
  end

  defp should_check?(source_file, excluded_modules, required_patterns) do
    filename = source_file.filename

    is_infrastructure? =
      (String.contains?(filename, "/infrastructure/") or
         String.contains?(filename, "/Infrastructure/")) and
        String.ends_with?(filename, ".ex") and
        not String.contains?(filename, "/test/")

    matches_required_pattern? =
      Enum.any?(required_patterns, &String.contains?(filename, &1))

    not_excluded? =
      not Enum.any?(excluded_modules, &String.contains?(filename, &1))

    is_infrastructure? and matches_required_pattern? and not_excluded?
  end

  defp check_for_behaviour(source_file, issue_meta) do
    source = SourceFile.source(source_file)

    # Check if module has @behaviour declaration
    has_behaviour? =
      Regex.match?(~r/@behaviour\s+[\w.]+/, source)

    if has_behaviour? do
      []
    else
      module_name = extract_module_name(source)

      [
        format_issue(
          issue_meta,
          message:
            "Infrastructure module `#{module_name}` does not implement a behaviour. " <>
              "Create a behaviour in application/behaviours/ and add @behaviour declaration. " <>
              "This enables dependency inversion and testability.",
          trigger: module_name,
          line_no: find_defmodule_line(source)
        )
      ]
    end
  end

  defp extract_module_name(source) do
    case Regex.run(~r/defmodule\s+([\w.]+)/, source) do
      [_, name] -> name
      _ -> "Unknown"
    end
  end

  defp find_defmodule_line(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(1, fn {line, idx} ->
      if String.contains?(line, "defmodule"), do: idx
    end)
  end
end
