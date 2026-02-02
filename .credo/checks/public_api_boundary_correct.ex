defmodule CredoChecks.CleanArchitecture.PublicApiBoundaryCorrect do
  @moduledoc """
  Verifies that the public API module (main app module) has correct boundary configuration.

  The public API module should:
  1. Have `use Boundary` declaration
  2. Only depend on the Application layer (not Infrastructure directly)
  3. Be the entry point that delegates to use cases

  ## Why This Matters

  The public API module is the facade for the entire app. It should:
  - Only expose what's needed by external callers
  - Delegate to use cases (not infrastructure)
  - Act as the single entry point

  ## Examples

  ### Correct Configuration

      defmodule MyApp do
        use Boundary,
          top_level?: true,
          deps: [MyApp.ApplicationLayer],
          exports: []

        # Delegates to use cases
        defdelegate create_user(attrs), to: MyApp.Application.UseCases.CreateUser, as: :execute
      end

  ### Incorrect - Depends on Infrastructure

      defmodule MyApp do
        use Boundary,
          top_level?: true,
          deps: [MyApp.Infrastructure],  # WRONG!
          exports: []
      end

  ## Configuration

  - `:excluded_apps` - Apps to skip checking (default: [])
  """

  use Credo.Check,
    id: "EX7006",
    base_priority: :higher,
    category: :design,
    exit_status: 2,
    param_defaults: [
      excluded_apps: [],
      presentation_suffixes: ["_web"],
      tools_suffixes: ["_tools"]
    ],
    explanations: [
      check: """
      Public API module must have correct boundary configuration.

      The main app module (e.g., `MyApp`) should:
      1. Have `use Boundary` with `top_level?: true`
      2. Only depend on ApplicationLayer: `deps: [MyApp.ApplicationLayer]`
      3. Not depend on Infrastructure directly

      This ensures the public API is a clean facade over the application layer.
      """,
      params: [
        excluded_apps: "App names to skip checking."
      ]
    ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Check main app module files (e.g., lib/my_app.ex)
    if is_main_app_module?(filename) do
      issue_meta = IssueMeta.for(source_file, params)
      check_public_api_boundary(source_file, issue_meta, params)
    else
      []
    end
  end

  defp is_main_app_module?(filename) do
    # Match files like "apps/my_app/lib/my_app.ex" or "lib/my_app.ex"
    # but not "lib/my_app/something.ex"
    basename = Path.basename(filename, ".ex")

    cond do
      # Umbrella app: apps/my_app/lib/my_app.ex
      match = Regex.run(~r/apps\/([^\/]+)\/lib\/([^\/]+)\.ex$/, filename) ->
        [_, app_name, file_name] = match
        app_name == file_name

      # Standalone app: lib/my_app.ex
      Regex.match?(~r/lib\/[^\/]+\.ex$/, filename) ->
        not String.ends_with?(basename, "_test")

      true ->
        false
    end
  end

  defp check_public_api_boundary(source_file, issue_meta, params) do
    filename = source_file.filename
    source = SourceFile.source(source_file)
    app_name = extract_app_name_from_filename(filename)

    # Check if excluded
    excluded_apps = Params.get(params, :excluded_apps, __MODULE__)

    if app_name in excluded_apps do
      []
    else
      # Skip presentation/tools apps
      presentation_suffixes = Params.get(params, :presentation_suffixes, __MODULE__)
      tools_suffixes = Params.get(params, :tools_suffixes, __MODULE__)

      if has_suffix?(app_name, presentation_suffixes ++ tools_suffixes) do
        []
      else
        validate_boundary(source, issue_meta, filename, app_name)
      end
    end
  end

  defp has_suffix?(app_name, suffixes) do
    Enum.any?(suffixes, &String.ends_with?(app_name, &1))
  end

  defp extract_app_name_from_filename(filename) do
    Path.basename(filename, ".ex")
  end

  defp validate_boundary(source, issue_meta, filename, app_name) do
    issues = []

    # Check 1: Must have use Boundary
    unless has_use_boundary?(source) do
      [
        format_issue(
          issue_meta,
          message:
            "Public API module `#{Macro.camelize(app_name)}` must have `use Boundary` declaration for architectural enforcement.",
          trigger: "use Boundary",
          filename: filename,
          line_no: find_defmodule_line(source)
        )
        | issues
      ]
    else
      # Check 2: Should have top_level?: true
      issues =
        unless has_top_level?(source) do
          [
            format_issue(
              issue_meta,
              message: "Public API module should have `top_level?: true` in Boundary config.",
              trigger: "top_level?",
              filename: filename,
              line_no: find_use_boundary_line(source)
            )
            | issues
          ]
        else
          issues
        end

      # Check 3: Should depend on ApplicationLayer, not Infrastructure
      deps = extract_deps(source)

      issues =
        if has_infrastructure_dep?(deps, app_name) do
          [
            format_issue(
              issue_meta,
              message:
                "Public API module should not depend on Infrastructure directly. " <>
                  "Change deps to `[#{Macro.camelize(app_name)}.ApplicationLayer]` instead.",
              trigger: "Infrastructure",
              filename: filename,
              line_no: find_use_boundary_line(source)
            )
            | issues
          ]
        else
          issues
        end

      # Check 4: Should have ApplicationLayer dependency (if it has use Boundary and is not empty deps)
      issues =
        if has_use_boundary?(source) and deps != [] and
             not has_application_dep?(deps, app_name) do
          [
            format_issue(
              issue_meta,
              message:
                "Public API module should depend on ApplicationLayer. " <>
                  "Expected `deps: [#{Macro.camelize(app_name)}.ApplicationLayer]`.",
              trigger: "deps",
              filename: filename,
              line_no: find_use_boundary_line(source)
            )
            | issues
          ]
        else
          issues
        end

      issues
    end
  end

  defp has_use_boundary?(source) do
    Regex.match?(~r/use\s+Boundary\b/, source)
  end

  defp has_top_level?(source) do
    Regex.match?(~r/top_level\?:\s*true/, source)
  end

  defp extract_deps(source) do
    cond do
      Regex.match?(~r/deps:\s*\[\s*\]/, source) ->
        []

      match = Regex.run(~r/deps:\s*\[([^\]]+)\]/, source) ->
        [_, deps_content] = match

        deps_content
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      true ->
        []
    end
  end

  defp has_infrastructure_dep?(deps, app_name) do
    infra_patterns = [
      "#{Macro.camelize(app_name)}.Infrastructure",
      "Infrastructure"
    ]

    Enum.any?(deps, fn dep ->
      Enum.any?(infra_patterns, &String.contains?(dep, &1))
    end)
  end

  defp has_application_dep?(deps, app_name) do
    app_patterns = [
      "#{Macro.camelize(app_name)}.ApplicationLayer",
      "#{Macro.camelize(app_name)}.Application",
      "ApplicationLayer"
    ]

    Enum.any?(deps, fn dep ->
      Enum.any?(app_patterns, fn pattern ->
        String.contains?(dep, pattern)
      end)
    end)
  end

  defp find_defmodule_line(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(1, fn {line, idx} ->
      if String.contains?(line, "defmodule"), do: idx
    end)
  end

  defp find_use_boundary_line(source) do
    source
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(1, fn {line, idx} ->
      if String.contains?(line, "use Boundary"), do: idx
    end)
  end
end
