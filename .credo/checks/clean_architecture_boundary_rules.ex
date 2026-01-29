defmodule CredoChecks.CleanArchitecture.BoundaryRules do
  @moduledoc """
  Verifies that Boundary definitions follow Clean Architecture dependency rules.

  ## Clean Architecture Dependency Rule

  Dependencies must point inward:

      Interface → Infrastructure → Application → Domain
                                              ↘   ↙
                                            (no deps)

  This means:
  - **Domain**: Must have `deps: []` (no dependencies)
  - **Application**: May only depend on Domain
  - **Infrastructure**: May depend on Domain and Application
  - **Interface** (Web/CLI): May depend on any layer

  ## What This Check Does

  1. Finds all `use Boundary` definitions in the codebase
  2. Determines the layer based on module path/name
  3. Verifies the `deps` list follows CA rules

  ## Layer Detection

  Layers are detected by module path patterns:
  - `*/domain/*` or `*.Domain` → Domain layer
  - `*/application/*` or `*.Application.*` (excluding OTP Application) → Application layer
  - `*/infrastructure/*` or `*.Infrastructure.*` → Infrastructure layer
  - `*_web/*` or `Mix.Tasks.*` → Interface layer

  ## Configuration

  - `:excluded_apps` - Apps to skip (default: [])
  - `:domain_patterns` - Patterns identifying domain modules
  - `:application_patterns` - Patterns identifying application modules
  - `:infrastructure_patterns` - Patterns identifying infrastructure modules

  ## Example

      {CredoChecks.CleanArchitecture.BoundaryRules, [
        excluded_apps: ["legacy_app"]
      ]}
  """

  use Credo.Check,
    id: "EX7004",
    base_priority: :higher,
    category: :design,
    exit_status: 2,
    param_defaults: [
      excluded_apps: [],
      domain_patterns: [~r/\.Domain\b/, ~r/\/domain\//],
      application_patterns: [~r/\.Application\.(?!$)/, ~r/\/application\//],
      infrastructure_patterns: [~r/\.Infrastructure\./, ~r/\/infrastructure\//],
      interface_patterns: [~r/_web\b/i, ~r/Mix\.Tasks\./]
    ],
    explanations: [
      check: """
      Boundary definitions must follow Clean Architecture dependency rules.

      **Domain layer** - The innermost layer, must have NO dependencies:
          use Boundary, deps: []

      **Application layer** - May only depend on Domain:
          use Boundary, deps: [MyApp.Domain]

      **Infrastructure layer** - May depend on Domain and Application:
          use Boundary, deps: [MyApp.Domain, MyApp.Application]

      **Interface layer** - May depend on any layer (entry point).

      If Domain depends on Infrastructure, the dependency rule is violated
      and the architecture becomes coupled to implementation details.
      """,
      params: [
        excluded_apps: "Apps to skip checking.",
        domain_patterns: "Regex patterns to identify domain layer modules.",
        application_patterns: "Regex patterns to identify application layer modules.",
        infrastructure_patterns: "Regex patterns to identify infrastructure layer modules.",
        interface_patterns: "Regex patterns to identify interface layer modules."
      ]
    ]

  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Only check .ex files (not mix.exs)
    if String.ends_with?(filename, ".ex") and not String.ends_with?(filename, "mix.exs") do
      check_boundary_rules(source_file, params)
    else
      []
    end
  end

  defp check_boundary_rules(source_file, params) do
    source = SourceFile.source(source_file)
    filename = source_file.filename

    # Check if file is in an excluded app
    excluded_apps = Params.get(params, :excluded_apps, __MODULE__)

    if excluded_by_app?(filename, excluded_apps) do
      []
    else
      # Find use Boundary definitions
      case extract_boundary_definition(source) do
        nil ->
          []

        {module_name, deps, line_no} ->
          layer = detect_layer(module_name, filename, params)
          validate_layer_deps(source_file, params, module_name, layer, deps, line_no)
      end
    end
  end

  defp excluded_by_app?(filename, excluded_apps) do
    Enum.any?(excluded_apps, fn app ->
      String.contains?(filename, "/apps/#{app}/") or
        String.contains?(filename, "/#{app}/lib/")
    end)
  end

  defp extract_boundary_definition(source) do
    # Match: use Boundary, deps: [...], ...
    # or: use Boundary, top_level?: true, deps: [...], ...
    # Need to handle multiline definitions

    # First, find if there's a `use Boundary` at all
    unless String.contains?(source, "use Boundary") do
      nil
    else
      # Extract module name
      module_name =
        case Regex.run(~r/defmodule\s+([\w.]+)/, source) do
          [_, name] -> name
          _ -> "Unknown"
        end

      # Find the line number of use Boundary
      line_no = find_use_boundary_line(source)

      # Extract deps - handle various formats
      deps = extract_deps(source)

      {module_name, deps, line_no}
    end
  end

  defp find_use_boundary_line(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(1, fn {line, idx} ->
      if String.contains?(line, "use Boundary"), do: idx
    end)
  end

  defp extract_deps(source) do
    # Try to find deps: [...] in various formats
    # Format 1: deps: []
    # Format 2: deps: [Module1, Module2]
    # Format 3: deps: [Module1.Sub, Module2.Sub]

    cond do
      # Empty deps
      Regex.match?(~r/deps:\s*\[\s*\]/, source) ->
        []

      # deps with modules
      match = Regex.run(~r/deps:\s*\[([^\]]+)\]/, source) ->
        [_, deps_content] = match

        deps_content
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&extract_module_name/1)
        |> Enum.reject(&is_nil/1)

      # No deps specified (defaults to empty in Boundary)
      true ->
        []
    end
  end

  defp extract_module_name(str) do
    # Handle formats like:
    # - ModuleName
    # - {ModuleName, []}
    # - Alias.ModuleName
    str = String.trim(str)

    cond do
      String.starts_with?(str, "{") ->
        case Regex.run(~r/\{([^,}]+)/, str) do
          [_, name] -> String.trim(name)
          _ -> nil
        end

      String.match?(str, ~r/^[A-Z][\w.]*$/) ->
        str

      true ->
        nil
    end
  end

  defp detect_layer(module_name, filename, params) do
    domain_patterns = Params.get(params, :domain_patterns, __MODULE__)
    application_patterns = Params.get(params, :application_patterns, __MODULE__)
    infrastructure_patterns = Params.get(params, :infrastructure_patterns, __MODULE__)
    interface_patterns = Params.get(params, :interface_patterns, __MODULE__)

    # Check patterns against both module name and filename
    combined = "#{module_name} #{filename}"

    cond do
      matches_any?(combined, interface_patterns) -> :interface
      matches_any?(combined, domain_patterns) -> :domain
      matches_any?(combined, application_patterns) -> :application
      matches_any?(combined, infrastructure_patterns) -> :infrastructure
      true -> :unknown
    end
  end

  defp matches_any?(string, patterns) do
    Enum.any?(patterns, fn pattern ->
      Regex.match?(pattern, string)
    end)
  end

  defp validate_layer_deps(source_file, params, module_name, layer, deps, line_no) do
    issue_meta = IssueMeta.for(source_file, params)

    case layer do
      :domain ->
        validate_domain_deps(issue_meta, source_file.filename, module_name, deps, line_no)

      :application ->
        validate_application_deps(
          issue_meta,
          source_file.filename,
          module_name,
          deps,
          line_no,
          params
        )

      :infrastructure ->
        # Infrastructure can depend on domain and application - fewer restrictions
        validate_infrastructure_deps(
          issue_meta,
          source_file.filename,
          module_name,
          deps,
          line_no,
          params
        )

      :interface ->
        # Interface can depend on anything
        []

      :unknown ->
        # Can't determine layer - skip validation
        []
    end
  end

  defp validate_domain_deps(issue_meta, filename, module_name, deps, line_no) do
    # Domain must have NO dependencies
    if deps == [] do
      []
    else
      [
        format_issue(
          issue_meta,
          message:
            "Clean Architecture violation: Domain layer `#{module_name}` must have `deps: []` but has deps: #{inspect(deps)}. Domain cannot depend on other layers.",
          trigger: "deps",
          filename: filename,
          line_no: line_no
        )
      ]
    end
  end

  defp validate_application_deps(issue_meta, filename, module_name, deps, line_no, params) do
    # Application may only depend on Domain
    infrastructure_patterns = Params.get(params, :infrastructure_patterns, __MODULE__)
    interface_patterns = Params.get(params, :interface_patterns, __MODULE__)

    forbidden_deps =
      Enum.filter(deps, fn dep ->
        matches_any?(dep, infrastructure_patterns) or
          matches_any?(dep, interface_patterns)
      end)

    if forbidden_deps == [] do
      []
    else
      [
        format_issue(
          issue_meta,
          message:
            "Clean Architecture violation: Application layer `#{module_name}` depends on #{inspect(forbidden_deps)}. Application may only depend on Domain.",
          trigger: "deps",
          filename: filename,
          line_no: line_no
        )
      ]
    end
  end

  defp validate_infrastructure_deps(issue_meta, filename, module_name, deps, line_no, params) do
    # Infrastructure may depend on Domain and Application, but not Interface
    interface_patterns = Params.get(params, :interface_patterns, __MODULE__)

    forbidden_deps =
      Enum.filter(deps, fn dep ->
        matches_any?(dep, interface_patterns)
      end)

    if forbidden_deps == [] do
      []
    else
      [
        format_issue(
          issue_meta,
          message:
            "Clean Architecture violation: Infrastructure layer `#{module_name}` depends on interface layer #{inspect(forbidden_deps)}. Infrastructure cannot depend on Interface.",
          trigger: "deps",
          filename: filename,
          line_no: line_no
        )
      ]
    end
  end
end
