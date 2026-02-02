defmodule Credo.Check.Custom.Architecture.InfrastructureUsesFileBehaviour do
  @moduledoc """
  Detects when infrastructure modules call File module directly instead of using
  an injected file system dependency.

  ## Clean Architecture Principle

  Even within the infrastructure layer, modules that depend on file operations
  should use injectable dependencies rather than calling File directly. This:
  - Enables testing without actual file system access
  - Maintains consistency with the rest of the architecture
  - Allows swapping implementations (memory, S3, etc.)

  ## Examples

  ### Invalid - Direct File calls in infrastructure:

      defmodule MyApp.Infrastructure.LayoutResolver do
        def resolve_layout(page, config, _opts) do
          layout_path = build_layout_path(page, config)

          if File.exists?(layout_path) do  # VIOLATION
            case File.read(layout_path) do  # VIOLATION
              {:ok, content} -> {:ok, content}
              {:error, _} -> {:error, :read_failed}
            end
          end
        end
      end

  ### Valid - Injectable file system dependency:

      defmodule MyApp.Infrastructure.LayoutResolver do
        def resolve_layout(page, config, opts \\\\ []) do
          file_system = Keyword.get(opts, :file_system, MyApp.Infrastructure.FileSystem)
          layout_path = build_layout_path(page, config)

          if file_system.exists?(layout_path) do
            case file_system.read(layout_path) do
              {:ok, content} -> {:ok, content}
              {:error, _} -> {:error, :read_failed}
            end
          end
        end
      end

  ## Configuration

  - `:excluded_modules` - Infrastructure modules allowed to use File directly
    (e.g., the FileSystem wrapper itself). Default: ["FileSystem"]
  """

  use Credo.Check,
    id: "EX8010",
    base_priority: :normal,
    category: :design,
    exit_status: 2,
    param_defaults: [
      excluded_modules: ["FileSystem", "file_system"]
    ],
    explanations: [
      check: """
      Infrastructure modules should use injectable file system dependencies.

      Even in the infrastructure layer, direct File module calls reduce testability.
      By accepting a file_system option, you can:
      - Test with mock file systems
      - Swap implementations easily
      - Maintain architectural consistency

      The only module that should call File directly is the FileSystem wrapper itself.

      Fix by:
      1. Accept file_system as an option parameter
      2. Use the injected dependency instead of File module
      3. Provide a default that uses the real FileSystem module
      """,
      params: [
        excluded_modules:
          "Module name patterns allowed to use File directly (e.g., FileSystem wrapper)."
      ]
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta
  alias Credo.Check.Params

  @file_operations [
    :exists?,
    :dir?,
    :regular?,
    :read,
    :read!,
    :write,
    :write!,
    :mkdir,
    :mkdir!,
    :mkdir_p,
    :mkdir_p!,
    :rm,
    :rm!,
    :rm_rf,
    :rm_rf!,
    :cp,
    :cp!,
    :cp_r,
    :cp_r!,
    :ls,
    :ls!,
    :stat,
    :stat!,
    :rename,
    :rename!,
    :open,
    :close
  ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    excluded_modules = Params.get(params, :excluded_modules, __MODULE__)

    if infrastructure_file?(source_file) and not excluded_module?(source_file, excluded_modules) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp infrastructure_file?(source_file) do
    filename = source_file.filename

    (String.contains?(filename, "/infrastructure/") or
       String.contains?(filename, "/Infrastructure/")) and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
  end

  defp excluded_module?(source_file, excluded_patterns) do
    filename = source_file.filename

    Enum.any?(excluded_patterns, fn pattern ->
      String.contains?(filename, pattern)
    end)
  end

  # Detect File.* calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:File]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in @file_operations do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "File.#{function}",
         "Direct File.#{function} call in infrastructure",
         "Accept file_system via opts and use file_system.#{function} instead"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, meta, trigger, description, suggestion) do
    format_issue(
      issue_meta,
      message:
        "#{description}. " <>
          "Infrastructure modules should use injectable file system for testability. " <>
          "#{suggestion}.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
