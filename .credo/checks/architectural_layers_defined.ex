defmodule CredoChecks.CleanArchitecture.ArchitecturalLayersDefined do
  @moduledoc """
  Checks that Clean Architecture layer definition files exist based on app type.

  ## App Types

  Apps are categorized by their role in the architecture:

  - **Core apps** (default): Business logic apps that need full Clean Architecture layers
  - **Presentation apps** (`*_web`): Interface layer apps that need only a presentation layer
  - **Tools apps** (`*_tools`): Utility apps that may not need layer definitions

  ## Required Layers by App Type

  ### Core Apps
  - `lib/{app}/domain.ex` - Domain layer boundary definition
  - `lib/{app}/application_layer.ex` - Application layer boundary definition
  - `lib/{app}/infrastructure_layer.ex` - Infrastructure layer boundary definition

  ### Presentation Apps (suffix: `_web`)
  - `lib/{app}/presentation.ex` - Presentation layer boundary definition

  ### Tools Apps (suffix: `_tools`)
  - No layer files required by default

  ## Configuration

  This check can be configured with:

  - `:core_layers` - Layers for core apps (default: domain.ex, application_layer.ex, infrastructure_layer.ex)
  - `:presentation_layers` - Layers for presentation apps (default: presentation.ex)
  - `:tools_layers` - Layers for tools apps (default: [])
  - `:presentation_suffixes` - App name suffixes for presentation apps (default: ["_web"])
  - `:tools_suffixes` - App name suffixes for tools apps (default: ["_tools"])
  - `:excluded_apps` - Apps to skip checking entirely (default: [])

  ## Example

      # .credo.exs
      {CredoChecks.CleanArchitecture.ArchitecturalLayersDefined, [
        core_layers: ["domain.ex", "application_layer.ex", "infrastructure_layer.ex"],
        presentation_layers: ["presentation.ex"],
        tools_layers: [],
        presentation_suffixes: ["_web", "_api"],
        excluded_apps: ["my_special_app"]
      ]}
  """

  use Credo.Check,
    id: "EX7002",
    base_priority: :high,
    category: :design,
    exit_status: 2,
    param_defaults: [
      core_layers: ["domain.ex", "application_layer.ex", "infrastructure_layer.ex"],
      presentation_layers: ["presentation.ex"],
      tools_layers: [],
      presentation_suffixes: ["_web"],
      tools_suffixes: ["_tools"],
      excluded_apps: []
    ],
    explanations: [
      check: """
      Clean Architecture layer definition files should be present based on app type.

      **Core apps** need:
      - `lib/{app}/domain.ex`
      - `lib/{app}/application_layer.ex`
      - `lib/{app}/infrastructure_layer.ex`

      **Presentation apps** (`*_web`) need:
      - `lib/{app}/presentation.ex`

      **Tools apps** (`*_tools`) have no requirements by default.
      """,
      params: [
        core_layers: "Layer files required for core apps.",
        presentation_layers: "Layer files required for presentation apps.",
        tools_layers: "Layer files required for tools apps.",
        presentation_suffixes: "App name suffixes that identify presentation apps.",
        tools_suffixes: "App name suffixes that identify tools apps.",
        excluded_apps: "App names to skip checking."
      ]
    ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Only check mix.exs files to determine app structure
    if Path.basename(filename) == "mix.exs" do
      issue_meta = IssueMeta.for(source_file, params)
      check_layer_files(source_file, issue_meta, params)
    else
      []
    end
  end

  defp check_layer_files(source_file, issue_meta, params) do
    mix_path = source_file.filename
    app_dir = Path.dirname(mix_path)
    source = SourceFile.source(source_file)

    case extract_app_name(source) do
      nil ->
        []

      app_name ->
        # Check if app is excluded
        excluded_apps = Params.get(params, :excluded_apps, __MODULE__)

        if app_name in excluded_apps do
          []
        else
          check_app_layers(app_name, app_dir, issue_meta, mix_path, params)
        end
    end
  end

  defp check_app_layers(app_name, app_dir, issue_meta, mix_path, params) do
    app_type = detect_app_type(app_name, params)
    required_layers = get_required_layers(app_type, params)
    lib_dir = Path.join(app_dir, "lib/#{app_name}")

    # Check each required layer file
    required_layers
    |> Enum.reject(&layer_file_exists?(lib_dir, &1))
    |> Enum.map(&issue_for(issue_meta, mix_path, app_name, &1, app_type))
  end

  defp detect_app_type(app_name, params) do
    presentation_suffixes = Params.get(params, :presentation_suffixes, __MODULE__)
    tools_suffixes = Params.get(params, :tools_suffixes, __MODULE__)

    cond do
      has_suffix?(app_name, presentation_suffixes) -> :presentation
      has_suffix?(app_name, tools_suffixes) -> :tools
      true -> :core
    end
  end

  defp has_suffix?(app_name, suffixes) do
    Enum.any?(suffixes, &String.ends_with?(app_name, &1))
  end

  defp get_required_layers(:core, params) do
    Params.get(params, :core_layers, __MODULE__)
  end

  defp get_required_layers(:presentation, params) do
    Params.get(params, :presentation_layers, __MODULE__)
  end

  defp get_required_layers(:tools, params) do
    Params.get(params, :tools_layers, __MODULE__)
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

  defp issue_for(issue_meta, filename, app_name, missing_layer, app_type) do
    layer_name = Path.rootname(missing_layer) |> String.replace("_", " ") |> String.capitalize()
    type_name = app_type_name(app_type)

    format_issue(
      issue_meta,
      message:
        "Clean Architecture: Missing #{layer_name} definition file `lib/#{app_name}/#{missing_layer}` for #{type_name}. Create this file with `use Boundary` to define architectural boundaries.",
      trigger: missing_layer,
      filename: filename,
      line_no: 1
    )
  end

  defp app_type_name(:core), do: "core app"
  defp app_type_name(:presentation), do: "presentation app"
  defp app_type_name(:tools), do: "tools app"
end
