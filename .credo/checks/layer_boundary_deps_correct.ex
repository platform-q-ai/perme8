defmodule CredoChecks.CleanArchitecture.LayerBoundaryDepsCorrect do
  @moduledoc """
  Verifies that layer boundary files have correct dependency configurations.

  This check ensures Clean Architecture is enforced by validating that:

  ## Domain Layer (`domain.ex`)
  - Must have `deps: []` (no dependencies)
  - Cannot depend on Application or Infrastructure

  ## Application Layer (`application_layer.ex` or `application.ex`)
  - Must only depend on Domain layer
  - Cannot depend on Infrastructure
  - Note: `application.ex` can serve dual purpose as OTP Application + boundary

  ## Infrastructure Layer (`infrastructure.ex`)
  - Must depend on Domain and Application layers
  - Cannot depend on Interface/Web layers

  ## Public API (main module)
  - Must only depend on Application layer
  - Cannot directly access Infrastructure

  ## Configuration

  - `:excluded_apps` - Apps to skip checking (default: [])
  - `:domain_file` - Domain layer file name (default: "domain.ex")
  - `:application_files` - Application layer file names (default: ["application_layer.ex", "application.ex"])
  - `:infrastructure_file` - Infrastructure layer file name (default: "infrastructure.ex")

  ## Example

      {CredoChecks.CleanArchitecture.LayerBoundaryDepsCorrect, [
        excluded_apps: ["legacy_app"]
      ]}
  """

  use Credo.Check,
    id: "EX7005",
    base_priority: :higher,
    category: :design,
    exit_status: 2,
    param_defaults: [
      excluded_apps: [],
      domain_file: "domain.ex",
      application_files: ["application_layer.ex", "application.ex"],
      infrastructure_file: "infrastructure.ex",
      presentation_suffixes: ["_web"],
      tools_suffixes: ["_tools"]
    ],
    explanations: [
      check: """
      Layer boundary files must have correct dependency configurations.

      **Domain** (`domain.ex`): `deps: []` - NO dependencies allowed
      **Application** (`application_layer.ex` or `application.ex`): `deps: [AppName.Domain]` - only Domain
      **Infrastructure** (`infrastructure.ex`): `deps: [AppName.Domain, AppName.Application]`

      The dependency rule is: Domain <- Application <- Infrastructure
      Dependencies flow inward; outer layers depend on inner layers.
      """,
      params: [
        excluded_apps: "App names to skip checking.",
        domain_file: "Filename for domain layer boundary.",
        application_files:
          "Filenames for application layer boundary (supports both naming conventions).",
        infrastructure_file: "Filename for infrastructure layer boundary."
      ]
    ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Check layer boundary files
    if is_layer_boundary_file?(filename, params) do
      issue_meta = IssueMeta.for(source_file, params)
      check_boundary_deps(source_file, issue_meta, params)
    else
      []
    end
  end

  defp is_layer_boundary_file?(filename, params) do
    domain_file = Params.get(params, :domain_file, __MODULE__)
    application_files = Params.get(params, :application_files, __MODULE__)
    infrastructure_file = Params.get(params, :infrastructure_file, __MODULE__)

    basename = Path.basename(filename)
    all_layer_files = [domain_file, infrastructure_file | application_files]

    basename in all_layer_files and
      String.contains?(filename, "/lib/") and
      not String.contains?(filename, "/test/")
  end

  defp check_boundary_deps(source_file, issue_meta, params) do
    filename = source_file.filename
    source = SourceFile.source(source_file)
    basename = Path.basename(filename)

    # Determine which layer this is
    domain_file = Params.get(params, :domain_file, __MODULE__)
    application_files = Params.get(params, :application_files, __MODULE__)
    infrastructure_file = Params.get(params, :infrastructure_file, __MODULE__)

    # Check if this app should be excluded
    excluded_apps = Params.get(params, :excluded_apps, __MODULE__)
    app_name = extract_app_name_from_path(filename)

    if app_name in excluded_apps do
      []
    else
      # Check for presentation/tools apps which have different rules
      presentation_suffixes = Params.get(params, :presentation_suffixes, __MODULE__)
      tools_suffixes = Params.get(params, :tools_suffixes, __MODULE__)

      if has_suffix?(app_name, presentation_suffixes ++ tools_suffixes) do
        # Skip layer checks for presentation/tools apps
        []
      else
        cond do
          basename == domain_file ->
            check_domain_deps(source, issue_meta, filename, app_name)

          basename in application_files ->
            # Only check if file has use Boundary (application.ex may be OTP-only)
            if has_use_boundary?(source) do
              check_application_deps(source, issue_meta, filename, app_name)
            else
              []
            end

          basename == infrastructure_file ->
            check_infrastructure_deps(source, issue_meta, filename, app_name)

          true ->
            []
        end
      end
    end
  end

  defp has_suffix?(app_name, suffixes) do
    Enum.any?(suffixes, &String.ends_with?(app_name, &1))
  end

  defp extract_app_name_from_path(filename) do
    # Extract app name from path like "apps/my_app/lib/my_app/domain.ex"
    case Regex.run(~r/apps\/([^\/]+)\/lib/, filename) do
      [_, app_name] -> app_name
      _ -> extract_from_lib_path(filename)
    end
  end

  defp extract_from_lib_path(filename) do
    # Try to extract from "lib/my_app/domain.ex"
    case Regex.run(~r/lib\/([^\/]+)\//, filename) do
      [_, app_name] -> app_name
      _ -> "unknown"
    end
  end

  # Extracts the context module prefix from a path.
  #
  # Examples:
  #   - "apps/jarga/lib/jarga/domain.ex" → "Jarga" (top-level, app folder matches app name)
  #   - "apps/jarga/lib/notifications/infrastructure.ex" → "Jarga.Notifications"
  #   - "apps/jarga/lib/documents/notes/domain.ex" → "Jarga.Documents.Notes"
  defp extract_context_module_prefix(filename, app_name) do
    app_module = Macro.camelize(app_name)

    # Extract path between lib/ and the layer file (domain.ex, application.ex, etc.)
    case Regex.run(~r/lib\/(.+)\/[^\/]+\.ex$/, filename) do
      [_, context_path] ->
        # Check if this is top-level (context path matches app name)
        if context_path == app_name do
          app_module
        else
          # Convert path segments to module names
          context_parts =
            context_path
            |> String.split("/")
            |> Enum.map(&Macro.camelize/1)
            |> Enum.join(".")

          "#{app_module}.#{context_parts}"
          |> String.replace("#{app_module}.#{app_module}", app_module)
        end

      _ ->
        app_module
    end
  end

  defp check_domain_deps(source, issue_meta, filename, app_name) do
    issues = []
    context_prefix = extract_context_module_prefix(filename, app_name)

    # Check 1: Must have use Boundary
    unless has_use_boundary?(source) do
      return_issue(issue_meta, filename, "Domain layer must have `use Boundary` declaration")
    else
      # Check 2: deps must be empty
      deps = extract_deps(source)

      if deps != [] do
        [
          format_issue(
            issue_meta,
            message:
              "Domain layer `#{context_prefix}.Domain` must have `deps: []` but has deps: #{inspect(deps)}. " <>
                "Domain layer cannot depend on any other layers.",
            trigger: "deps",
            filename: filename,
            line_no: find_use_boundary_line(source)
          )
          | issues
        ]
      else
        issues
      end
    end
  end

  defp check_application_deps(source, issue_meta, filename, app_name) do
    issues = []
    context_prefix = extract_context_module_prefix(filename, app_name)

    unless has_use_boundary?(source) do
      return_issue(issue_meta, filename, "Application layer must have `use Boundary` declaration")
    else
      deps = extract_deps(source)
      domain_module = "#{context_prefix}.Domain"
      context_has_domain = context_layer_exists?(filename, "domain.ex")

      cond do
        # Only require Domain dependency if context HAS a Domain layer
        context_has_domain and not has_context_domain_dep?(deps, context_prefix) ->
          [
            format_issue(
              issue_meta,
              message:
                "Application layer must depend on Domain layer. Expected `deps: [#{domain_module}]` but got: #{inspect(deps)}",
              trigger: "deps",
              filename: filename,
              line_no: find_use_boundary_line(source)
            )
            | issues
          ]

        # Must NOT have Infrastructure dependency (for this context) - this is always a violation
        has_context_infrastructure_dep?(deps, context_prefix) ->
          [
            format_issue(
              issue_meta,
              message:
                "Application layer cannot depend on Infrastructure layer. Remove Infrastructure from deps: #{inspect(deps)}",
              trigger: "deps",
              filename: filename,
              line_no: find_use_boundary_line(source)
            )
            | issues
          ]

        true ->
          issues
      end
    end
  end

  defp check_infrastructure_deps(source, issue_meta, filename, app_name) do
    issues = []
    context_prefix = extract_context_module_prefix(filename, app_name)

    unless has_use_boundary?(source) do
      return_issue(
        issue_meta,
        filename,
        "Infrastructure layer must have `use Boundary` declaration"
      )
    else
      deps = extract_deps(source)
      context_has_domain = context_layer_exists?(filename, "domain.ex")

      context_has_application =
        context_layer_exists?(filename, "application.ex") or
          context_layer_exists?(filename, "application_layer.ex")

      cond do
        # Only require Domain dependency if context HAS a Domain layer
        context_has_domain and
          not has_context_domain_dep?(deps, context_prefix) and
            not has_parent_domain_dep?(deps, context_prefix) ->
          [
            format_issue(
              issue_meta,
              message:
                "Infrastructure layer must depend on Domain layer. Add `#{context_prefix}.Domain` to deps.",
              trigger: "deps",
              filename: filename,
              line_no: find_use_boundary_line(source)
            )
            | issues
          ]

        # Only require Application dependency if context HAS an Application layer
        context_has_application and
            not has_context_application_dep?(deps, context_prefix) ->
          [
            format_issue(
              issue_meta,
              message:
                "Infrastructure layer must depend on Application layer. Add `#{context_prefix}.Application` to deps.",
              trigger: "deps",
              filename: filename,
              line_no: find_use_boundary_line(source)
            )
            | issues
          ]

        true ->
          issues
      end
    end
  end

  # Check if a sibling layer file exists in the same context directory
  defp context_layer_exists?(infrastructure_file, layer_filename) do
    context_dir = Path.dirname(infrastructure_file)
    layer_path = Path.join(context_dir, layer_filename)
    File.exists?(layer_path)
  end

  defp has_use_boundary?(source) do
    Regex.match?(~r/use\s+Boundary\b/, source)
  end

  defp extract_deps(source) do
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

      true ->
        []
    end
  end

  defp extract_module_name(str) do
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

  # Context-aware dependency checks

  defp has_context_domain_dep?(deps, context_prefix) do
    # Check if deps contain the context's own Domain layer
    domain_module = "#{context_prefix}.Domain"

    Enum.any?(deps, fn dep ->
      String.contains?(dep, domain_module) or dep == domain_module
    end)
  end

  defp has_parent_domain_dep?(deps, context_prefix) do
    # Check if deps contain a parent context's Domain layer
    # e.g., Jarga.Documents.Notes might depend on Jarga.Documents.Domain or Jarga.Domain
    parent_prefixes = get_parent_prefixes(context_prefix)

    Enum.any?(deps, fn dep ->
      Enum.any?(parent_prefixes, fn parent ->
        String.contains?(dep, "#{parent}.Domain")
      end)
    end)
  end

  defp has_context_application_dep?(deps, context_prefix) do
    # Check if deps contain the context's own Application layer
    app_patterns = [
      "#{context_prefix}.Application",
      "#{context_prefix}.ApplicationLayer"
    ]

    Enum.any?(deps, fn dep ->
      Enum.any?(app_patterns, fn pattern ->
        String.contains?(dep, pattern) or dep == pattern
      end)
    end)
  end

  defp has_context_infrastructure_dep?(deps, context_prefix) do
    # Check if deps contain the context's own Infrastructure layer
    infra_module = "#{context_prefix}.Infrastructure"

    Enum.any?(deps, fn dep ->
      String.contains?(dep, infra_module) or dep == infra_module
    end)
  end

  defp get_parent_prefixes(context_prefix) do
    # Get all parent prefixes for a context
    # e.g., "Jarga.Documents.Notes" -> ["Jarga.Documents", "Jarga"]
    parts = String.split(context_prefix, ".")

    parts
    |> Enum.with_index()
    |> Enum.filter(fn {_, idx} -> idx < length(parts) - 1 end)
    |> Enum.map(fn {_, idx} ->
      parts
      |> Enum.take(idx + 1)
      |> Enum.join(".")
    end)
    |> Enum.reverse()
  end

  defp find_use_boundary_line(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(1, fn {line, idx} ->
      if String.contains?(line, "use Boundary"), do: idx
    end)
  end

  defp return_issue(issue_meta, filename, message) do
    [
      format_issue(
        issue_meta,
        message: message,
        trigger: "use Boundary",
        filename: filename,
        line_no: 1
      )
    ]
  end
end
