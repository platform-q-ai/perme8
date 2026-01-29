defmodule Credo.Check.Custom.Architecture.InterfaceLayerUsesPublicApi do
  @moduledoc """
  Ensures Mix tasks (interface layer) use the public API instead of calling use cases directly.

  ## Clean Architecture Violation

  The interface layer (Mix tasks, controllers, LiveViews) should interact with the
  application through its public API module, not by directly calling internal use cases.

  This provides:
  - Encapsulation of internal structure
  - Single entry point for all external interactions
  - Easier refactoring of internal organization
  - Clear API contract

  ## Examples

  ### Invalid - Mix task calls use case directly:

      defmodule Mix.Tasks.Alkali.New do
        use Mix.Task
        alias Alkali.Application.UseCases.ScaffoldNewSite  # WRONG

        def run([name | _]) do
          # WRONG: Calling use case directly
          case ScaffoldNewSite.execute(name) do
            {:ok, _} -> Mix.shell().info("Created!")
            {:error, reason} -> Mix.shell().error(reason)
          end
        end
      end

  ### Valid - Mix task uses public API:

      defmodule Mix.Tasks.Alkali.New do
        use Mix.Task

        def run([name | _]) do
          # CORRECT: Using public API
          case Alkali.new_site(name) do
            {:ok, _} -> Mix.shell().info("Created!")
            {:error, reason} -> Mix.shell().error(reason)
          end
        end
      end

      # In lib/alkali.ex (public API):
      defmodule Alkali do
        alias Alkali.Application.UseCases.ScaffoldNewSite

        def new_site(name, opts \\\\ []) do
          ScaffoldNewSite.execute(name, opts)
        end
      end

  ## Why This Matters

  1. **Encapsulation**: Internal structure hidden from external callers
  2. **Maintainability**: Can refactor use cases without breaking Mix tasks
  3. **Documentation**: Public API is the documented interface
  4. **Testing**: Can test public API independently
  """

  use Credo.Check,
    base_priority: :normal,
    category: :design,
    explanations: [
      check: """
      Mix tasks should use the public API module, not call use cases directly.

      Benefits:
      - Encapsulates internal application structure
      - Provides single entry point
      - Easier refactoring
      - Clear API contract

      Fix by:
      1. Add a public function to the main module (e.g., Alkali.new_site/2)
      2. Have the Mix task call that function instead of the use case
      3. The public function delegates to the use case internally
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    if mix_task_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp mix_task_file?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "/mix/tasks/") and
      String.ends_with?(filename, ".ex") and
      not String.contains?(filename, "/test/")
  end

  # Detect alias of use case modules
  defp traverse(
         {:alias, meta, [{:__aliases__, _, module_parts}]} = ast,
         issues,
         issue_meta
       ) do
    module_string = Enum.map(module_parts, &to_string/1) |> Enum.join(".")

    issues =
      if use_case_module?(module_string) do
        [
          issue_for(
            issue_meta,
            meta,
            "alias #{module_string}",
            "Aliasing use case module in Mix task",
            extract_app_name(module_string)
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect direct calls to UseCases modules
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    module_string = Enum.map(module_parts, &to_string/1) |> Enum.join(".")

    issues =
      if use_case_module?(module_string) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{module_string}.#{function}",
            "Direct use case call in Mix task",
            extract_app_name(module_string)
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp use_case_module?(module_string) do
    String.contains?(module_string, "Application.UseCases") or
      String.contains?(module_string, "Application.UseCase") or
      String.contains?(module_string, ".UseCases.")
  end

  defp extract_app_name(module_string) do
    module_string
    |> String.split(".")
    |> List.first()
  end

  defp issue_for(issue_meta, meta, trigger, description, app_name) do
    format_issue(
      issue_meta,
      message:
        "Mix task bypasses public API (#{description}). " <>
          "Interface layer should use the public API (#{app_name} module) instead of calling use cases directly. " <>
          "Add a public function to #{app_name} that delegates to the use case, then call that from the Mix task.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
