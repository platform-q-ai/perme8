defmodule CredoChecks.CleanArchitecture.BoundaryEnforcementConfigured do
  @moduledoc """
  Checks that the Boundary library is properly configured for compile-time enforcement.

  This check verifies:
  1. The `:boundary` compiler is in the compilers list
  2. At least one `use Boundary` definition exists in the app

  This is more robust than checking for specific layer files because:
  - It verifies actual enforcement, not just file existence
  - It works with any boundary structure (layers, contexts, etc.)
  - It lets the Boundary library handle the actual rules

  ## Why This Matters

  Installing the boundary package is not enough - it must be:
  1. Added to the compilers list to run during compilation
  2. Actually used via `use Boundary` in at least one module

  Without both, no architectural enforcement happens.

  ## Configuration

  - `:excluded_apps` - Apps to skip checking (default: [])
  - `:min_boundaries` - Minimum number of boundaries required (default: 1)

  ## Example

      # .credo.exs
      {CredoChecks.CleanArchitecture.BoundaryEnforcementConfigured, [
        excluded_apps: ["my_simple_app"],
        min_boundaries: 1
      ]}
  """

  use Credo.Check,
    id: "EX7003",
    base_priority: :high,
    category: :design,
    exit_status: 2,
    param_defaults: [
      excluded_apps: [],
      min_boundaries: 1
    ],
    explanations: [
      check: """
      The Boundary library must be properly configured for architectural enforcement.

      1. Add `:boundary` to your compilers in mix.exs:

          def project do
            [
              ...
              compilers: [:boundary] ++ Mix.compilers(),
              ...
            ]
          end

      2. Define at least one boundary using `use Boundary`:

          defmodule MyApp.Domain do
            use Boundary,
              deps: [],
              exports: [...]
          end

      The Boundary library will then enforce dependency rules at compile time.
      """,
      params: [
        excluded_apps: "App names to skip checking.",
        min_boundaries: "Minimum number of `use Boundary` definitions required."
      ]
    ]

  @doc false
  @impl true
  def run(%SourceFile{filename: filename} = source_file, params) do
    # Only check mix.exs files
    if Path.basename(filename) == "mix.exs" do
      issue_meta = IssueMeta.for(source_file, params)
      check_boundary_configuration(source_file, issue_meta, params)
    else
      []
    end
  end

  defp check_boundary_configuration(source_file, issue_meta, params) do
    mix_path = source_file.filename
    app_dir = Path.dirname(mix_path)
    source = SourceFile.source(source_file)

    case extract_app_name(source) do
      nil ->
        []

      app_name ->
        excluded_apps = Params.get(params, :excluded_apps, __MODULE__)

        if app_name in excluded_apps do
          []
        else
          issues = []

          # Check 1: Boundary package is installed
          issues =
            if has_boundary_dep?(source) do
              issues
            else
              [boundary_dep_issue(issue_meta, mix_path) | issues]
            end

          # Check 2: Boundary compiler is configured
          issues =
            if has_boundary_compiler?(source) do
              issues
            else
              [boundary_compiler_issue(issue_meta, mix_path) | issues]
            end

          # Check 3: At least one use Boundary exists in the app
          min_boundaries = Params.get(params, :min_boundaries, __MODULE__)
          boundary_count = count_boundary_usages(app_dir, app_name)

          issues =
            if boundary_count >= min_boundaries do
              issues
            else
              [
                boundary_usage_issue(issue_meta, mix_path, boundary_count, min_boundaries)
                | issues
              ]
            end

          issues
        end
    end
  end

  defp extract_app_name(source) do
    case Regex.run(~r/app:\s*:(\w+)/, source) do
      [_, app_name] -> app_name
      _ -> nil
    end
  end

  defp has_boundary_dep?(source) do
    String.contains?(source, "{:boundary,")
  end

  defp has_boundary_compiler?(source) do
    # Check for :boundary in compilers list
    # Matches patterns like:
    #   compilers: [:boundary] ++ Mix.compilers()
    #   compilers: [:boundary, :phoenix_live_view] ++ Mix.compilers()
    Regex.match?(~r/compilers:\s*\[.*:boundary.*\]/, source)
  end

  defp count_boundary_usages(app_dir, _app_name) do
    lib_dir = Path.join(app_dir, "lib")

    if File.dir?(lib_dir) do
      lib_dir
      |> find_elixir_files()
      |> Enum.count(&file_has_use_boundary?/1)
    else
      0
    end
  end

  defp find_elixir_files(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          path = Path.join(dir, entry)

          cond do
            File.dir?(path) -> find_elixir_files(path)
            String.ends_with?(entry, ".ex") -> [path]
            true -> []
          end
        end)

      {:error, _} ->
        []
    end
  end

  defp file_has_use_boundary?(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Match `use Boundary` with optional options
        Regex.match?(~r/use\s+Boundary\b/, content)

      {:error, _} ->
        false
    end
  end

  defp boundary_dep_issue(issue_meta, filename) do
    format_issue(
      issue_meta,
      message:
        "Boundary: Package not installed. Add `{:boundary, \"~> 0.10\", runtime: false}` to deps.",
      trigger: "deps",
      filename: filename,
      line_no: 1
    )
  end

  defp boundary_compiler_issue(issue_meta, filename) do
    format_issue(
      issue_meta,
      message:
        "Boundary: Compiler not configured. Add `compilers: [:boundary] ++ Mix.compilers()` to project config.",
      trigger: "compilers",
      filename: filename,
      line_no: 1
    )
  end

  defp boundary_usage_issue(issue_meta, filename, actual, required) do
    format_issue(
      issue_meta,
      message:
        "Boundary: Found #{actual} boundary definition(s), need at least #{required}. Add `use Boundary` to define architectural boundaries.",
      trigger: "use Boundary",
      filename: filename,
      line_no: 1
    )
  end
end
