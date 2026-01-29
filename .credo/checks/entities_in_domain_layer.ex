defmodule Credo.Check.Custom.Architecture.EntitiesInDomainLayer do
  @moduledoc """
  Ensures all Ecto schemas (domain entities) are located in `domain/entities/` subdirectory.

  This check enforces Clean Architecture by ensuring domain entities are:
  1. Clearly separated from other layers
  2. Located in a consistent, predictable location
  3. Not mixed with infrastructure or application code

  ## Current Violations

  Entities at wrong locations:
  - `lib/jarga/accounts/user.ex` → Should be `lib/jarga/accounts/domain/entities/user.ex`
  - `lib/jarga/agents/infrastructure/agent.ex` → Should be `lib/jarga/agents/domain/entities/agent.ex`
  - `lib/jarga/documents/document.ex` → Should be `lib/jarga/documents/domain/entities/document.ex`

  ## Expected Structure

      lib/jarga/{context}/
      └── domain/
          └── entities/
              ├── {entity}.ex        # Ecto schemas here
              └── ...

  ## Configuration

      {Credo.Check.Custom.Architecture.EntitiesInDomainLayer, []}

  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Entities (Ecto schemas) should be in domain/entities/ subdirectory.

      Domain entities represent the core business concepts and should be
      clearly separated from infrastructure and application logic.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    file_path = source_file.filename

    # Only check context modules that use Ecto.Schema
    if is_context_module?(file_path) and uses_ecto_schema?(source_file) do
      check_entity_location(file_path, issue_meta)
    else
      []
    end
  end

  # Check if file is in a context (lib/jarga/{context}/)
  defp is_context_module?(file_path) do
    String.match?(file_path, ~r|lib/jarga/[^/]+/.+\.ex$|) and
      not String.contains?(file_path, "lib/jarga_web") and
      not String.contains?(file_path, "test/") and
      not String.contains?(file_path, "repo.ex") and
      not String.contains?(file_path, "mailer.ex") and
      not String.contains?(file_path, "application.ex")
  end

  # Check if source uses Ecto.Schema
  defp uses_ecto_schema?(source_file) do
    source_file
    |> SourceFile.source()
    |> String.contains?("use Ecto.Schema")
  end

  # Verify entity is in domain/entities/ subdirectory
  defp check_entity_location(file_path, issue_meta) do
    cond do
      # ✅ Correct location: domain/entities/
      String.match?(file_path, ~r|/domain/entities/[^/]+\.ex$|) ->
        []

      # ❌ VIOLATION: Entity in infrastructure layer
      String.contains?(file_path, "/infrastructure/") ->
        [
          create_issue(
            issue_meta,
            "Entity in infrastructure layer",
            get_correct_path(file_path, :from_infrastructure),
            1
          )
        ]

      # ❌ VIOLATION: Entity at context root
      String.match?(file_path, ~r|lib/jarga/[^/]+/[^/]+\.ex$|) ->
        [
          create_issue(
            issue_meta,
            "Entity at context root",
            get_correct_path(file_path, :from_root),
            1
          )
        ]

      # ❌ VIOLATION: Entity in wrong subdirectory
      true ->
        [
          create_issue(
            issue_meta,
            "Entity in wrong location",
            get_correct_path(file_path, :generic),
            1
          )
        ]
    end
  end

  # Generate correct path based on violation type
  defp get_correct_path(file_path, violation_type) do
    case violation_type do
      :from_infrastructure ->
        # lib/jarga/agents/infrastructure/agent.ex → lib/jarga/agents/domain/entities/agent.ex
        String.replace(file_path, ~r|/infrastructure/([^/]+\.ex)$|, "/domain/entities/\\1")

      :from_root ->
        # lib/jarga/accounts/user.ex → lib/jarga/accounts/domain/entities/user.ex
        String.replace(file_path, ~r|(lib/jarga/[^/]+)/([^/]+\.ex)$|, "\\1/domain/entities/\\2")

      :generic ->
        file_name = Path.basename(file_path)
        context = extract_context(file_path)
        "lib/jarga/#{context}/domain/entities/#{file_name}"
    end
  end

  # Extract context name from file path
  defp extract_context(file_path) do
    case Regex.run(~r|lib/jarga/([^/]+)/|, file_path) do
      [_, context] -> context
      _ -> "unknown"
    end
  end

  # Create Credo issue
  defp create_issue(issue_meta, trigger, correct_path, line_no) do
    format_issue(
      issue_meta,
      message:
        "Ecto schema (entity) should be in domain/entities/ subdirectory.\n" <>
          "  Current location violates Clean Architecture layer separation.\n" <>
          "  Move to: #{correct_path}",
      trigger: trigger,
      line_no: line_no
    )
  end
end
