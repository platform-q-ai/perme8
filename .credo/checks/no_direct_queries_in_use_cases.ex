defmodule Jarga.Credo.Check.Architecture.NoDirectQueriesInUseCases do
  @moduledoc """
  Detects direct Ecto queries in UseCase modules.

  ## Clean Architecture Violation

  Use cases should orchestrate domain logic and infrastructure, but should not
  contain raw database queries. Database queries belong in:
  - Query objects (*.Queries modules)
  - Repository modules (*.Infrastructure.*Repository)
  - Context public functions

  Per ARCHITECTURE.md lines 241-249: Use cases should "Use infrastructure for
  data access", not contain raw Ecto queries directly.

  ## Examples

  ### Invalid - Direct query in use case:

      defmodule Jarga.Workspaces.UseCases.InviteMember do
        import Ecto.Query  # ❌ Importing Ecto.Query in use case

        def execute(email, workspace_id) do
          # ❌ Raw query in use case
          user = from(u in User,
            where: fragment("LOWER(?)", u.email) == ^String.downcase(email)
          ) |> Repo.one()

          # ... rest of logic
        end
      end

  ### Valid - Delegate to repository/context:

      defmodule Jarga.Workspaces.UseCases.InviteMember do
        # ✅ Delegating to context or repository
        def execute(email, workspace_id) do
          user = Accounts.get_user_by_email_case_insensitive(email)

          # ... rest of logic
        end
      end

  ### Valid - Query in repository module:

      defmodule Jarga.Accounts do
        import Ecto.Query

        def get_user_by_email_case_insensitive(email) do
          downcased = String.downcase(email)

          from(u in User,
            where: fragment("LOWER(?)", u.email) == ^downcased
          )
          |> Repo.one()
        end
      end
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      Use case modules should not contain raw Ecto queries.

      Use cases orchestrate business operations by calling:
      - Domain logic (pure functions)
      - Infrastructure services (repos, queries)
      - External services

      Database queries should be extracted to:
      - Query objects (composable query builders)
      - Repository functions (data access layer)
      - Context public APIs (for cross-context data access)

      This ensures:
      - Single Responsibility Principle
      - Reusable queries across use cases
      - Easier testing with mocks
      - Clear architectural boundaries
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check UseCase modules
    if use_case_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp use_case_file?(source_file) do
    String.contains?(source_file.filename, "/use_cases/") and
      String.ends_with?(source_file.filename, ".ex")
  end

  # Check for import Ecto.Query
  defp traverse({:import, meta, [{:__aliases__, _, [:Ecto, :Query]}]} = ast, issues, issue_meta) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "import Ecto.Query",
         "Importing Ecto.Query in use case"
       )
       | issues
     ]}
  end

  # Check for from(...) Ecto.Query calls
  defp traverse({:from, meta, _args} = ast, issues, issue_meta) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "from",
         "Direct Ecto query with from(...)"
       )
       | issues
     ]}
  end

  # Check for direct Repo module references in function bodies
  # We want to catch: Repo.one(), Repo.all(), etc.
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if repo_query_function?(module_parts, function) do
        [
          issue_for(
            issue_meta,
            meta,
            "Repo.#{function}",
            "Direct Repo.#{function}() call"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Check for fragment() calls (usually indicate raw SQL in queries)
  defp traverse({:fragment, meta, _args} = ast, issues, issue_meta) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "fragment",
         "SQL fragment in use case"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  # Check if this is a Repo query function
  defp repo_query_function?(module_parts, function) do
    List.last(module_parts) == :Repo and
      function in [:get, :get!, :get_by, :get_by!, :all, :one, :one!, :insert, :update, :delete, :preload]
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Use case contains direct database query (#{description}). " <>
          "Extract queries to Query objects, Repository modules, or Context functions. " <>
          "Use cases should orchestrate, not query (Clean Architecture).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
