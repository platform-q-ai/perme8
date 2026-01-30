defmodule Mix.Tasks.Check.Behaviours do
  @shortdoc "Verifies all injected infrastructure modules implement behaviours"

  @moduledoc """
  Systematically verifies Clean Architecture behaviour compliance across all apps.

  This task automatically detects dependency injection patterns and verifies
  that all injected infrastructure modules implement corresponding behaviours.

  ## Usage

      # Check all apps
      mix check.behaviours

      # Check specific app
      mix check.behaviours --app alkali

      # Verbose output
      mix check.behaviours --verbose

  ## What it checks

  1. **Scans all use case modules** in `*.Application.UseCases.*` namespaces
  2. **Detects injection patterns**:
     - `defp default_*` functions returning infrastructure modules
     - `Keyword.get(opts, :key, Infrastructure.Module)` patterns
  3. **Verifies each infrastructure module**:
     - Implements at least one behaviour
     - The behaviour is defined in the Application layer

  ## Exit codes

  - 0: All checks passed
  - 1: Architecture violations found
  """

  use Mix.Task
  use Boundary, top_level?: true

  @switches [app: :string, verbose: :boolean]
  @aliases [a: :app, v: :verbose]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    # Compile to ensure all modules are loaded
    Mix.Task.run("compile", ["--force"])

    app_filter = Keyword.get(opts, :app)
    verbose = Keyword.get(opts, :verbose, false)

    violations = find_all_violations(app_filter, verbose)

    if violations == [] do
      Mix.shell().info([
        :green,
        "\n✓ All infrastructure modules implement behaviours correctly\n"
      ])
    else
      print_violations(violations)
      exit({:shutdown, 1})
    end
  end

  defp find_all_violations(app_filter, verbose) do
    apps = discover_apps(app_filter)

    if verbose do
      Mix.shell().info([:cyan, "Checking apps: #{inspect(apps)}\n"])
    end

    apps
    |> Enum.flat_map(&check_app(&1, verbose))
  end

  defp discover_apps(nil) do
    # Find all apps in umbrella
    Path.wildcard("apps/*/mix.exs")
    |> Enum.map(fn path ->
      path
      |> Path.dirname()
      |> Path.basename()
    end)
    |> Enum.reject(&String.ends_with?(&1, "_tools"))
  end

  defp discover_apps(app_name), do: [app_name]

  defp check_app(app_name, verbose) do
    if verbose do
      Mix.shell().info([:yellow, "Scanning #{Macro.camelize(app_name)}...\n"])
    end

    use_case_files = find_use_case_files(app_name)

    if verbose do
      Mix.shell().info("  Found #{length(use_case_files)} use case files\n")
    end

    use_case_files
    |> Enum.flat_map(&check_use_case_file(&1, app_name, verbose))
  end

  defp find_use_case_files(app_name) do
    patterns = [
      # Standard Clean Architecture: lib/app_name/application/use_cases/
      "apps/#{app_name}/lib/#{app_name}/application/use_cases/**/*.ex",
      "apps/#{app_name}/lib/#{app_name}/application_layer/use_cases/**/*.ex",
      # Bounded Context structure: lib/context_name/application/use_cases/
      "apps/#{app_name}/lib/*/application/use_cases/**/*.ex",
      "apps/#{app_name}/lib/*/application_layer/use_cases/**/*.ex"
    ]

    patterns
    |> Enum.flat_map(&Path.wildcard/1)
    |> Enum.uniq()
  end

  defp check_use_case_file(file_path, app_name, verbose) do
    source_code = File.read!(file_path)

    # Extract module prefix from file path
    # For "apps/jarga/lib/accounts/application/use_cases/foo.ex" -> "Accounts"
    # For "apps/alkali/lib/alkali/application/use_cases/foo.ex" -> "Alkali"
    module_prefix = extract_module_prefix(file_path, app_name)

    injected_modules = find_injected_modules(source_code, module_prefix)

    if verbose and injected_modules != [] do
      Mix.shell().info(
        "  #{Path.basename(file_path)}: found #{length(injected_modules)} injected modules (prefix: #{module_prefix})\n"
      )
    end

    injected_modules
    |> Enum.flat_map(&verify_behaviour(&1, file_path))
  end

  defp extract_module_prefix(file_path, app_name) do
    # Extract the context/module name from the path
    # For bounded contexts (context != app_name):
    #   "apps/jarga/lib/accounts/application/use_cases/foo.ex" -> "Jarga.Accounts"
    # For standard structure (context == app_name):
    #   "apps/alkali/lib/alkali/application/use_cases/foo.ex" -> "Alkali"
    case Regex.run(~r/apps\/#{app_name}\/lib\/(\w+)\/application/, file_path) do
      [_, context] when context == app_name ->
        # Standard structure: lib/app_name/application/
        Macro.camelize(app_name)

      [_, context] ->
        # Bounded context structure: lib/context_name/application/
        # Module prefix is App.Context (e.g., Jarga.Accounts)
        "#{Macro.camelize(app_name)}.#{Macro.camelize(context)}"

      nil ->
        Macro.camelize(app_name)
    end
  end

  defp find_injected_modules(source_code, module_prefix) do
    escaped_prefix = Regex.escape(module_prefix)

    # Pattern 1: defp default_*, do: Module.Name
    pattern1 =
      ~r/defp\s+default_\w+\s*(?:\(\))?\s*,\s*do:\s*(#{escaped_prefix}\.Infrastructure[\w.]*)/

    # Pattern 2: defp default_*() do\n  Module.Name\nend
    pattern2 =
      ~r/defp\s+default_\w+\s*(?:\(\))?\s*do\s+(#{escaped_prefix}\.Infrastructure[\w.]*)\s+end/

    # Pattern 3: Keyword.get(opts, :key, Module.Name) - direct module reference
    pattern3 =
      ~r/Keyword\.get\s*\(\s*\w+\s*,\s*:\w+\s*,\s*(#{escaped_prefix}\.Infrastructure[\w.]*)\s*\)/

    # Pattern 4: @default_* Module.Name - module attribute style (used in Jarga)
    pattern4 =
      ~r/@default_\w+\s+(#{escaped_prefix}\.Infrastructure[\w.]*)/

    matches1 = Regex.scan(pattern1, source_code) |> Enum.map(&Enum.at(&1, 1))
    matches2 = Regex.scan(pattern2, source_code) |> Enum.map(&Enum.at(&1, 1))
    matches3 = Regex.scan(pattern3, source_code) |> Enum.map(&Enum.at(&1, 1))
    matches4 = Regex.scan(pattern4, source_code) |> Enum.map(&Enum.at(&1, 1))

    (matches1 ++ matches2 ++ matches3 ++ matches4)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.map(&safe_to_module/1)
    |> Enum.reject(&is_nil/1)
  end

  defp safe_to_module(module_string) do
    String.to_existing_atom("Elixir.#{module_string}")
  rescue
    ArgumentError -> nil
  end

  defp verify_behaviour(module, use_case_file) do
    behaviours = get_behaviours(module)

    cond do
      behaviours == [] ->
        [{module, use_case_file, :no_behaviour}]

      not has_application_behaviour?(behaviours, module) ->
        [{module, use_case_file, {:wrong_layer, behaviours}}]

      true ->
        []
    end
  end

  defp get_behaviours(module) do
    module.module_info(:attributes)[:behaviour] || []
  rescue
    _ -> []
  end

  defp has_application_behaviour?(behaviours, module) do
    # Extract the context prefix from the module
    # For "Jarga.Accounts.Infrastructure.Repositories.UserRepository" -> "Jarga.Accounts"
    # For "Alkali.Infrastructure.FileSystem" -> "Alkali"
    context_prefix = extract_context_prefix(module)

    Enum.any?(behaviours, fn behaviour ->
      behaviour_str = Atom.to_string(behaviour)

      # Check if behaviour is in the same context's Application layer
      # e.g., "Jarga.Accounts.Application.Behaviours.UserRepositoryBehaviour"
      String.contains?(behaviour_str, "#{context_prefix}.Application") and
        String.contains?(behaviour_str, "Behaviour")
    end)
  end

  defp extract_context_prefix(module) do
    # Parse module to find context prefix (everything before .Infrastructure)
    # "Elixir.Jarga.Accounts.Infrastructure.Repositories.X" -> "Jarga.Accounts"
    # "Elixir.Alkali.Infrastructure.X" -> "Alkali"
    module
    |> Atom.to_string()
    |> String.replace_prefix("Elixir.", "")
    |> String.split(".Infrastructure")
    |> hd()
  end

  defp print_violations(violations) do
    Mix.shell().error([:red, "\n✗ Clean Architecture Violations Found:\n"])

    violations
    |> Enum.group_by(fn {module, _file, _reason} -> module end)
    |> Enum.each(fn {module, instances} ->
      {_, file, reason} = hd(instances)

      Mix.shell().error([
        :yellow,
        "\n  #{inspect(module)}\n",
        :reset,
        "    Injected in: #{Path.relative_to_cwd(file)}\n",
        :red,
        "    Problem: #{format_reason(reason)}\n",
        :cyan,
        "    Fix: #{suggest_fix(module, reason)}\n"
      ])
    end)

    Mix.shell().error([
      :white,
      "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n",
      :cyan,
      "To fix these violations:\n",
      :reset,
      "  1. Create a behaviour in the Application layer:\n",
      "     lib/app_name/application/behaviours/module_name_behaviour.ex\n",
      "  2. Add @behaviour to the infrastructure module\n",
      "  3. Implement all callbacks with @impl true\n"
    ])
  end

  defp format_reason(:no_behaviour) do
    "Does not implement any behaviour"
  end

  defp format_reason({:wrong_layer, behaviours}) do
    "Implements #{inspect(behaviours)} but none are Application layer behaviours"
  end

  defp suggest_fix(module, :no_behaviour) do
    # Extract suggested behaviour name from module
    module_name =
      module
      |> Atom.to_string()
      |> String.split(".")
      |> List.last()

    context_prefix = extract_context_prefix(module)

    "Create #{context_prefix}.Application.Behaviours.#{module_name}Behaviour"
  end

  defp suggest_fix(module, {:wrong_layer, _}) do
    context_prefix = extract_context_prefix(module)
    "Move the behaviour definition to #{context_prefix}.Application.Behaviours"
  end
end
