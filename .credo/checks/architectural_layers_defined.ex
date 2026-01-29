defmodule CredoChecks.CleanArchitecture.ArchitecturalLayersDefined do
  @moduledoc """
  Checks that Clean Architecture layer definition files exist.

  For each app, the following layer definition files should exist:

  - `lib/{app}/domain.ex` - Domain layer boundary definition
  - `lib/{app}/application_layer.ex` - Application layer boundary definition
  - `lib/{app}/infrastructure_layer.ex` - Infrastructure layer boundary definition

  ## Why This Matters

  Layer definition files serve two purposes:

  1. **Boundary Definitions**: They contain `use Boundary` declarations that
     specify what each layer can depend on and what it exports.

  2. **Documentation**: They provide a single place to document what each
     layer contains and its architectural responsibilities.

  ## What Each Layer Should Contain

  ### Domain Layer (`domain.ex`)
  - Entities (pure data structures)
  - Policies (business rules)
  - Value objects
  - No external dependencies

  ### Application Layer (`application_layer.ex`)
  - Use cases (business operations)
  - Behaviours (contracts for infrastructure)
  - Depends only on Domain layer

  ### Infrastructure Layer (`infrastructure_layer.ex`)
  - Implementations of behaviours
  - External service adapters
  - Parsers, renderers, file system access
  - Depends on Domain and Application behaviours

  ## Configuration

  This check can be configured with:

  - `:layers` - List of required layer files (default: ["domain.ex", "application_layer.ex", "infrastructure_layer.ex"])
  - `:exit_status` - The exit status to use (default: 2)

  ## Example

      # .credo.exs
      {CredoChecks.CleanArchitecture.ArchitecturalLayersDefined, [
        layers: ["domain.ex", "application_layer.ex", "infrastructure_layer.ex"]
      ]}
  """

  use Credo.Check,
    id: "EX7002",
    base_priority: :high,
    category: :design,
    exit_status: 2,
    param_defaults: [
      layers: ["domain.ex", "application_layer.ex", "infrastructure_layer.ex"]
    ],
    explanations: [
      check: """
      Clean Architecture layer definition files should be present.

      Create the following files in your app's lib directory:

      1. `lib/{app}/domain.ex` - Define domain boundary:
         ```elixir
         defmodule MyApp.Domain do
           use Boundary, deps: [], exports: [...]
         end
         ```

      2. `lib/{app}/application_layer.ex` - Define application boundary:
         ```elixir
         defmodule MyApp.ApplicationLayer do
           use Boundary, deps: [MyApp.Domain], exports: [...]
         end
         ```

      3. `lib/{app}/infrastructure_layer.ex` - Define infrastructure boundary:
         ```elixir
         defmodule MyApp.InfrastructureLayer do
           use Boundary, deps: [MyApp.Domain, MyApp.ApplicationLayer], exports: [...]
         end
         ```
      """,
      params: [
        layers: "List of required layer definition files."
      ]
    ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Only check mix.exs files to determine app structure
    if Path.basename(filename) == "mix.exs" do
      issue_meta = IssueMeta.for(source_file, params)
      required_layers = Params.get(params, :layers, __MODULE__)
      check_layer_files(source_file, issue_meta, required_layers)
    else
      []
    end
  end

  defp check_layer_files(source_file, issue_meta, required_layers) do
    mix_path = source_file.filename
    app_dir = Path.dirname(mix_path)

    # Extract app name from mix.exs
    source = SourceFile.source(source_file)

    case extract_app_name(source) do
      nil ->
        []

      app_name ->
        lib_dir = Path.join(app_dir, "lib/#{app_name}")

        # Check each required layer file
        required_layers
        |> Enum.reject(&layer_file_exists?(lib_dir, &1))
        |> Enum.map(&issue_for(issue_meta, mix_path, app_name, &1))
    end
  end

  defp extract_app_name(source) do
    # Match `app: :app_name` in mix.exs
    case Regex.run(~r/app:\s*:(\w+)/, source) do
      [_, app_name] -> app_name
      _ -> nil
    end
  end

  defp layer_file_exists?(lib_dir, layer_file) do
    path = Path.join(lib_dir, layer_file)
    File.exists?(path)
  end

  defp issue_for(issue_meta, filename, app_name, missing_layer) do
    layer_name = Path.rootname(missing_layer) |> String.replace("_", " ") |> String.capitalize()

    format_issue(
      issue_meta,
      message:
        "Clean Architecture: Missing #{layer_name} definition file `lib/#{app_name}/#{missing_layer}`. Create this file with `use Boundary` to define architectural boundaries.",
      trigger: missing_layer,
      filename: filename,
      line_no: 1
    )
  end
end
