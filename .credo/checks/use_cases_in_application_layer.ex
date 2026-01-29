defmodule Credo.Check.Custom.Architecture.UseCasesInApplicationLayer do
  @moduledoc """
  Ensures all use case modules are located in `application/use_cases/` subdirectory.

  This check enforces Clean Architecture by ensuring use cases (application layer logic) are:
  1. Clearly separated from domain and infrastructure layers
  2. Located in a consistent, predictable location
  3. Easy to identify as application-level orchestration

  ## Current Violations

  Use cases at wrong locations:
  - `lib/jarga/accounts/use_cases/` → Should be `lib/jarga/accounts/application/use_cases/`
  - `lib/jarga/agents/use_cases/` → Should be `lib/jarga/agents/application/use_cases/`
  - `lib/jarga/documents/use_cases/` → Should be `lib/jarga/documents/application/use_cases/`

  ## Expected Structure

      lib/jarga/{context}/
      └── application/
          └── use_cases/
              ├── {use_case}.ex
              └── ...

  ## Configuration

      {Credo.Check.Custom.Architecture.UseCasesInApplicationLayer, []}

  """

  @explanation [check: @moduledoc]

  use Credo.Check,
    base_priority: :high,
    category: :design,
    exit_status: 2

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    file_path = source_file.filename

    # Only check use case modules
    if is_use_case_module?(file_path) do
      check_use_case_location(file_path, issue_meta)
    else
      []
    end
  end

  # Check if this is a use case module
  defp is_use_case_module?(file_path) do
    # Must be in lib/jarga/{context}/use_cases/ or lib/jarga/{context}/application/use_cases/
    String.match?(file_path, ~r|lib/jarga/[^/]+/.*use_cases/[^/]+\.ex$|) and
      not String.contains?(file_path, "test/")
  end

  # Verify use case is in application/use_cases/ subdirectory
  defp check_use_case_location(file_path, issue_meta) do
    cond do
      # ✅ Correct location: application/use_cases/
      String.match?(file_path, ~r|/application/use_cases/[^/]+\.ex$|) ->
        []

      # ❌ VIOLATION: Use case at wrong location
      String.match?(file_path, ~r|lib/jarga/[^/]+/use_cases/[^/]+\.ex$|) ->
        module_name = extract_module_name(file_path)
        correct_path = get_correct_path(file_path)

        [
          create_issue(
            issue_meta,
            module_name,
            "Use case not in application layer",
            correct_path,
            1
          )
        ]

      true ->
        []
    end
  end

  # Generate correct path
  defp get_correct_path(file_path) do
    # lib/jarga/accounts/use_cases/update_user_email.ex 
    # → lib/jarga/accounts/application/use_cases/update_user_email.ex
    String.replace(file_path, ~r|(lib/jarga/[^/]+)/use_cases/|, "\\1/application/use_cases/")
  end

  # Extract module name from file path
  defp extract_module_name(file_path) do
    case Regex.run(~r|lib/jarga/([^/]+)(?:/.+)?/use_cases/([^/]+)\.ex$|, file_path) do
      [_, context, file_name] ->
        module_parts = [String.capitalize(context), "UseCases", Macro.camelize(file_name)]
        "Jarga.#{Enum.join(module_parts, ".")}"

      _ ->
        "UnknownModule"
    end
  end

  # Create Credo issue
  defp create_issue(issue_meta, module_name, trigger, correct_path, line_no) do
    format_issue(
      issue_meta,
      message:
        "Use case `#{module_name}` should be in application/use_cases/ subdirectory.\n" <>
          "  Use cases are application layer concerns and should be organized accordingly.\n" <>
          "  Move to: #{correct_path}",
      trigger: trigger,
      line_no: line_no
    )
  end
end
