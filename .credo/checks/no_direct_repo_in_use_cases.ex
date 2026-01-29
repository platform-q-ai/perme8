defmodule Credo.Check.Custom.Architecture.NoDirectRepoInUseCases do
  @moduledoc """
  Ensures use cases don't directly use Repo - they should delegate to repositories.

  ## Clean Architecture Violation

  Application layer (use cases) should not directly depend on infrastructure (Repo).
  This violates the Repository pattern and makes testing harder.

  Use cases should delegate to repository modules which abstract data access.

  Per PHOENIX_DESIGN_PRINCIPLES.md:
  - Application layer orchestrates domain logic
  - Infrastructure layer handles persistence
  - Repositories provide abstraction over data access
  - Use cases should be testable with mocked repositories

  ## Examples

  ### Invalid - Direct Repo usage in use case:

      # lib/jarga/agents/application/use_cases/create_session.ex
      defmodule Jarga.Agents.Application.UseCases.CreateSession do
        alias Jarga.Repo  # ❌ WRONG - Direct Repo dependency
        alias Jarga.Agents.Domain.Entities.ChatSession

        def execute(attrs) do
          %ChatSession{}
          |> ChatSession.changeset(attrs)
          |> Repo.insert()  # ❌ WRONG - Direct Repo call
        end
      end

  ### Valid - Use repository:

      # lib/jarga/agents/application/use_cases/create_session.ex
      defmodule Jarga.Agents.Application.UseCases.CreateSession do
        alias Jarga.Agents.Infrastructure.Repositories.SessionRepository  # ✅ OK

        def execute(attrs) do
          SessionRepository.create_session(attrs)  # ✅ OK - Delegates to repository
        end
      end

  ### Valid - Repository implementation:

      # lib/jarga/agents/infrastructure/repositories/session_repository.ex
      defmodule Jarga.Agents.Infrastructure.Repositories.SessionRepository do
        alias Jarga.Repo  # ✅ OK - Repo in infrastructure layer
        alias Jarga.Agents.Infrastructure.Schemas.ChatSessionSchema

        def create_session(attrs) do
          %ChatSessionSchema{}
          |> ChatSessionSchema.changeset(attrs)
          |> Repo.insert()  # ✅ OK - Repository can use Repo
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Use cases should not directly use Repo - delegate to repositories instead.

      Benefits:
      - Application layer independent of persistence details
      - Easy to mock for testing
      - Single place to modify data access logic
      - Follows Repository pattern
      - Enforces Clean Architecture boundaries
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check use case files
    if use_case_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp use_case_file?(source_file) do
    path = source_file.filename

    # Check if in application/use_cases/ directory, but exclude test files
    String.contains?(path, "/application/use_cases/") and
      not (String.starts_with?(path, "test/") or String.contains?(path, "/test/"))
  end

  # Detect: alias Jarga.Repo
  defp traverse(
         {:alias, meta, [{:__aliases__, _, module_parts}]} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if repo_alias?(module_parts) do
        [
          issue_for(
            issue_meta,
            meta,
            "alias #{format_module(module_parts)}",
            "Direct Repo alias in use case"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect: Repo.insert(), Repo.get(), etc.
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Repo]}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [
              :insert,
              :insert!,
              :update,
              :update!,
              :delete,
              :delete!,
              :get,
              :get!,
              :get_by,
              :get_by!,
              :all,
              :one,
              :one!,
              :preload,
              :transaction
            ] do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "Repo.#{function}",
         "Direct Repo call in use case"
       )
       | issues
     ]}
  end

  # Detect: Full module path Repo calls (e.g., Jarga.Repo.insert)
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       )
       when function in [
              :insert,
              :insert!,
              :update,
              :update!,
              :delete,
              :delete!,
              :get,
              :get!,
              :get_by,
              :get_by!,
              :all,
              :one,
              :one!,
              :preload,
              :transaction
            ] do
    issues =
      if repo_alias?(module_parts) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{format_module(module_parts)}.#{function}",
            "Direct Repo call in use case"
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

  # Check if module is a Repo module
  defp repo_alias?(module_parts) do
    module_name = format_module(module_parts)
    String.ends_with?(module_name, ".Repo") or module_name == "Repo"
  end

  defp format_module(module_parts) do
    Enum.join(module_parts, ".")
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Use case contains direct Repo usage (#{description}). " <>
          "Application layer should not directly depend on infrastructure (Repo). " <>
          "Delegate to repository modules (e.g., AgentRepository.create_agent/1) " <>
          "to maintain Clean Architecture boundaries and improve testability.",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
