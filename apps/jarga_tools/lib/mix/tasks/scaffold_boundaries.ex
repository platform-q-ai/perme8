defmodule Mix.Tasks.Scaffold.Boundaries do
  @shortdoc "Scaffolds Clean Architecture layer boundary files for an app"

  @moduledoc """
  Scaffolds Clean Architecture layer boundary files for an umbrella app.

  ## Usage

      mix scaffold.boundaries APP_NAME [OPTIONS]

  ## Options

    * `--force` - Overwrite existing files
    * `--dry-run` - Show what would be created without creating files

  ## Examples

      # Scaffold boundaries for a new app
      mix scaffold.boundaries my_app

      # Preview what would be created
      mix scaffold.boundaries my_app --dry-run

      # Overwrite existing files
      mix scaffold.boundaries my_app --force

  ## What Gets Created

  For core apps:

    * `lib/my_app/domain.ex` - Domain layer boundary (deps: [])
    * `lib/my_app/application_layer.ex` - Application layer boundary (deps: Domain)
    * `lib/my_app/infrastructure.ex` - Infrastructure layer boundary (deps: Domain, Application)
    * Updates `lib/my_app.ex` - Public API with correct boundary config

  For web apps (suffix: _web):

    * `lib/my_app_web/presentation.ex` - Presentation layer boundary

  ## Notes

  This task assumes an umbrella project structure with apps in the `apps/` directory.
  """

  use Mix.Task
  use Boundary, top_level?: true

  @switches [force: :boolean, dry_run: :boolean]
  @aliases [f: :force, n: :dry_run]

  @impl Mix.Task
  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case args do
      [app_name] ->
        scaffold_app(app_name, opts)

      [] ->
        Mix.shell().error("Usage: mix scaffold.boundaries APP_NAME [--force] [--dry-run]")
        exit({:shutdown, 1})

      _ ->
        Mix.shell().error("Too many arguments. Expected: mix scaffold.boundaries APP_NAME")
        exit({:shutdown, 1})
    end
  end

  defp scaffold_app(app_name, opts) do
    app_dir = Path.join(["apps", app_name])

    unless File.dir?(app_dir) do
      Mix.shell().error("App directory not found: #{app_dir}")
      Mix.shell().info("Make sure the app exists in the umbrella project.")
      exit({:shutdown, 1})
    end

    lib_dir = Path.join([app_dir, "lib", app_name])

    unless File.dir?(lib_dir) do
      Mix.shell().error("Lib directory not found: #{lib_dir}")
      exit({:shutdown, 1})
    end

    # Determine app type
    app_type = detect_app_type(app_name)
    module_name = Macro.camelize(app_name)

    Mix.shell().info("Scaffolding #{app_type} boundaries for #{module_name}...")
    Mix.shell().info("")

    case app_type do
      :core ->
        scaffold_core_app(app_name, lib_dir, module_name, opts)

      :presentation ->
        scaffold_presentation_app(app_name, lib_dir, module_name, opts)

      :tools ->
        scaffold_tools_app(app_name, lib_dir, module_name, opts)
    end

    Mix.shell().info("")
    Mix.shell().info("Done! Run `mix compile` to verify boundaries.")
  end

  defp detect_app_type(app_name) do
    cond do
      String.ends_with?(app_name, "_web") -> :presentation
      String.ends_with?(app_name, "_tools") -> :tools
      true -> :core
    end
  end

  defp scaffold_core_app(app_name, lib_dir, module_name, opts) do
    # Domain layer
    create_file(
      Path.join(lib_dir, "domain.ex"),
      domain_template(module_name),
      opts
    )

    # Application layer
    create_file(
      Path.join(lib_dir, "application_layer.ex"),
      application_layer_template(module_name),
      opts
    )

    # Infrastructure layer
    create_file(
      Path.join(lib_dir, "infrastructure.ex"),
      infrastructure_template(module_name),
      opts
    )

    # Update public API
    public_api_path = Path.join(["apps", app_name, "lib", "#{app_name}.ex"])
    update_public_api(public_api_path, module_name, opts)
  end

  defp scaffold_presentation_app(_app_name, lib_dir, module_name, opts) do
    create_file(
      Path.join(lib_dir, "presentation.ex"),
      presentation_template(module_name),
      opts
    )
  end

  defp scaffold_tools_app(_app_name, _lib_dir, module_name, _opts) do
    Mix.shell().info("Tools app #{module_name} - no layer files required.")
    Mix.shell().info("Add `use Boundary` to #{module_name} module if needed.")
  end

  defp create_file(path, content, opts) do
    dry_run = Keyword.get(opts, :dry_run, false)
    force = Keyword.get(opts, :force, false)

    exists = File.exists?(path)

    cond do
      dry_run ->
        status = if exists, do: "[would overwrite]", else: "[would create]"
        Mix.shell().info("#{status} #{path}")

      exists and not force ->
        Mix.shell().info("[skip] #{path} (already exists, use --force to overwrite)")

      true ->
        File.write!(path, content)
        status = if exists, do: "[overwrite]", else: "[create]"
        Mix.shell().info("#{status} #{path}")
    end
  end

  defp update_public_api(path, module_name, opts) do
    dry_run = Keyword.get(opts, :dry_run, false)

    cond do
      not File.exists?(path) ->
        Mix.shell().info("[skip] #{path} (not found)")

      has_boundary_config?(path) ->
        Mix.shell().info("[skip] #{path} (already has Boundary config)")

      dry_run ->
        Mix.shell().info("[would update] #{path}")

        Mix.shell().info(
          "  Add: use Boundary, top_level?: true, deps: [#{module_name}.ApplicationLayer]"
        )

      true ->
        apply_boundary_config(path, module_name)
    end
  end

  defp has_boundary_config?(path) do
    content = File.read!(path)
    String.contains?(content, "use Boundary")
  end

  defp apply_boundary_config(path, module_name) do
    content = File.read!(path)
    updated = inject_boundary_config(content, module_name)
    File.write!(path, updated)
    Mix.shell().info("[update] #{path}")
  end

  defp inject_boundary_config(content, module_name) do
    # Find the line after defmodule and @moduledoc
    # Insert use Boundary there
    boundary_config = """
      use Boundary,
        top_level?: true,
        deps: [#{module_name}.ApplicationLayer],
        exports: []

    """

    # Try to insert after @moduledoc block
    cond do
      # Has @moduledoc with heredoc
      Regex.match?(~r/@moduledoc\s+"""[\s\S]*?"""/, content) ->
        Regex.replace(
          ~r/(@moduledoc\s+"""[\s\S]*?""")\n/,
          content,
          "\\1\n\n#{boundary_config}",
          global: false
        )

      # Has @moduledoc false
      String.contains?(content, "@moduledoc false") ->
        String.replace(
          content,
          "@moduledoc false\n",
          "@moduledoc false\n\n#{boundary_config}",
          global: false
        )

      # No @moduledoc, insert after defmodule
      true ->
        Regex.replace(
          ~r/(defmodule\s+\S+\s+do)\n/,
          content,
          "\\1\n#{boundary_config}",
          global: false
        )
    end
  end

  defp domain_template(module_name) do
    """
    defmodule #{module_name}.Domain do
      @moduledoc \"\"\"
      Domain layer boundary for #{module_name}.

      Contains pure business logic with NO external dependencies:

      ## Entities (Data Structures)
      - Define your domain entities here

      ## Policies (Business Rules)
      - Define your business rule modules here

      ## Dependency Rule

      The Domain layer has NO dependencies. It cannot import:
      - Application layer (use cases, services)
      - Infrastructure layer (repos, external services)
      - External libraries (Ecto, HTTP clients, etc.)
      \"\"\"

      use Boundary,
        top_level?: true,
        deps: [],
        exports: [
          # Add your entities and policies here, e.g.:
          # Entities.User,
          # Policies.AuthPolicy
        ]
    end
    """
  end

  defp application_layer_template(module_name) do
    """
    defmodule #{module_name}.ApplicationLayer do
      @moduledoc \"\"\"
      Application layer boundary for #{module_name}.

      Contains orchestration logic that coordinates domain and infrastructure:

      ## Behaviours (Interfaces for Infrastructure)
      - Define behaviours that infrastructure must implement

      ## Use Cases
      - Define use case modules that orchestrate operations

      ## Dependency Rule

      The Application layer may only depend on:
      - Domain layer (same context)

      It cannot import:
      - Infrastructure layer (repos, external services)
      - Other contexts directly (use dependency injection)
      \"\"\"

      use Boundary,
        top_level?: true,
        deps: [#{module_name}.Domain],
        exports: [
          # Add your use cases and behaviours here, e.g.:
          # UseCases.CreateUser,
          # Behaviours.UserRepoBehaviour
        ]
    end
    """
  end

  defp infrastructure_template(module_name) do
    """
    defmodule #{module_name}.Infrastructure do
      @moduledoc \"\"\"
      Infrastructure layer boundary for #{module_name}.

      Contains implementations that interact with external systems:

      ## Repositories
      - Data access implementations

      ## Schemas
      - Ecto schemas for database tables

      ## Services
      - External service integrations

      ## Dependency Rule

      The Infrastructure layer may depend on:
      - Domain layer (for entities and policies)
      - Application layer (to implement behaviours)

      It can use external libraries (Ecto, HTTP clients, etc.)
      \"\"\"

      use Boundary,
        top_level?: true,
        deps: [
          #{module_name}.Domain,
          #{module_name}.ApplicationLayer
        ],
        exports: [
          # Add your repositories and services here, e.g.:
          # Repositories.UserRepository,
          # Schemas.UserSchema
        ]
    end
    """
  end

  defp presentation_template(module_name) do
    """
    defmodule #{module_name}.Presentation do
      @moduledoc \"\"\"
      Presentation layer boundary for #{module_name}.

      Contains UI components and view-related logic:

      ## Components
      - LiveView components
      - Function components

      ## Hooks
      - JavaScript hooks

      ## Dependency Rule

      The Presentation layer depends on the core app's public API.
      It should not access infrastructure directly.
      \"\"\"

      use Boundary,
        top_level?: true,
        deps: [],
        exports: []
    end
    """
  end
end
