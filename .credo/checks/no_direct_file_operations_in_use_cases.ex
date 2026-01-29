defmodule Credo.Check.Custom.Architecture.NoDirectFileOperationsInUseCases do
  @moduledoc """
  Detects direct File module calls in use cases that should use injectable dependencies.

  ## Clean Architecture Violation

  Use cases should orchestrate domain logic and delegate I/O to infrastructure.
  Direct File module calls in use cases:
  - Make testing difficult (require actual file system)
  - Violate Dependency Inversion Principle
  - Couple application logic to implementation details

  ## Why This Matters

  1. **Testability**: Can't mock File operations without dependency injection
  2. **Dependency Inversion**: Use cases depend on abstraction, not concrete File module
  3. **Single Responsibility**: Use cases orchestrate, infrastructure does I/O
  4. **Flexibility**: Can swap file system implementations (memory, S3, etc.)

  ## Examples

  ### Invalid - Direct File calls in use case:

      defmodule MyApp.Application.UseCases.BuildSite do
        def execute(site_path, opts \\\\ []) do
          # WRONG: Direct file operations
          if File.exists?(config_path) do
            content = File.read!(config_path)
            File.mkdir_p!(output_path)
            File.write!(output_file, rendered)
          end
        end

        defp collect_files(path) do
          # WRONG: Direct Path.wildcard
          Path.wildcard(Path.join(path, "**/*.md"))
        end
      end

  ### Valid - Injectable file system dependency:

      defmodule MyApp.Application.UseCases.BuildSite do
        alias MyApp.Infrastructure.FileSystem

        def execute(site_path, opts \\\\ []) do
          # Use injectable dependency with default
          fs = Keyword.get(opts, :file_system, FileSystem)

          if fs.exists?(config_path) do
            content = fs.read!(config_path)
            fs.mkdir_p!(output_path)
            fs.write!(output_file, rendered)
          end
        end

        defp collect_files(path, fs) do
          fs.wildcard(Path.join(path, "**/*.md"))
        end
      end

      # In tests:
      test "builds site" do
        mock_fs = MockFileSystem.new()
        BuildSite.execute("/path", file_system: mock_fs)
      end

  ## Detected Operations

  - `File.exists?/1`, `File.dir?/1`
  - `File.read/1`, `File.read!/1`
  - `File.write/2`, `File.write!/2`
  - `File.mkdir/1`, `File.mkdir_p/1`, `File.mkdir_p!/1`
  - `File.rm/1`, `File.rm_rf/1`
  - `File.cp/2`, `File.cp_r/2`
  - `File.ls/1`
  - `Path.wildcard/1`, `Path.wildcard/2`
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Use cases should not call File module directly - use injectable dependencies.

      This ensures:
      - Testability (mock file operations)
      - Dependency Inversion (depend on abstraction)
      - Flexibility (swap implementations)

      Fix by:
      1. Create/use a FileSystem infrastructure module
      2. Accept file_system as an option with default
      3. Use the injected dependency instead of File module

      Example:
        def execute(path, opts \\\\ []) do
          fs = Keyword.get(opts, :file_system, MyApp.Infrastructure.FileSystem)
          fs.read!(path)  # Instead of File.read!(path)
        end
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

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

  @path_operations [
    :wildcard
  ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    if use_case_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp use_case_file?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "/application/use_cases/") and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
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
         "Direct File.#{function} call",
         "Inject file_system dependency via opts"
       )
       | issues
     ]}
  end

  # Detect Path.wildcard calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Path]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in @path_operations do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "Path.#{function}",
         "Direct Path.#{function} call",
         "Use file_system.wildcard/1 instead"
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
        "Use case contains direct file operation (#{description}). " <>
          "Use cases should use injectable file system dependencies for testability. " <>
          "#{suggestion}. " <>
          "Example: fs = Keyword.get(opts, :file_system, FileSystem); fs.#{extract_function(trigger)}(...)",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end

  defp extract_function(trigger) do
    trigger
    |> String.split(".")
    |> List.last()
  end
end
