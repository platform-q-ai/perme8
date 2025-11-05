defmodule Jarga.Credo.Check.Architecture.NoInlineQueriesInContexts do
  @moduledoc """
  Detects inline Ecto queries in context modules that should be extracted to Query objects.

  ## Clean Architecture Violation

  Context modules should delegate to Query objects for all database queries.
  Inline queries in contexts make them:
  - Non-reusable
  - Non-composable
  - Harder to test
  - Inconsistent with established patterns

  Per ARCHITECTURE.md lines 365-398:
  ```
  Query Objects:
  - Extract complex queries into dedicated query modules
  - Keep repositories thin by delegating to query objects
  - Make queries composable and reusable
  ```

  Per CLAUDE.md: "Query Objects: Extract complex queries into dedicated query
  modules. Keep queries composable and reusable."

  ## What Should Use Query Objects

  All contexts should follow the pattern:
  - **Context** → calls → **Queries** → returns queryable → **Repo.one/all/etc**

  Queries should be extracted when:
  - Using `from(...)` in context functions
  - Using `fragment()` for SQL
  - Building dynamic queries with `where/join/etc`
  - Any Ecto.Query operations

  ## Examples

  ### Invalid - Inline query in context:

      defmodule Jarga.Accounts do
        import Ecto.Query

        # ❌ Inline query with fragment in context
        def get_user_by_email_case_insensitive(email) do
          downcased = String.downcase(email)

          from(u in User,
            where: fragment("LOWER(?)", u.email) == ^downcased
          )
          |> Repo.one()
        end
      end

  ### Valid - Extract to Query object:

      defmodule Jarga.Accounts.Queries do
        import Ecto.Query
        alias Jarga.Accounts.User

        def base, do: from(u in User)

        def by_email_case_insensitive(query, email) do
          downcased = String.downcase(email)
          where(query, [u], fragment("LOWER(?)", u.email) == ^downcased)
        end
      end

      defmodule Jarga.Accounts do
        alias Jarga.Accounts.Queries

        # ✅ Delegates to Query object
        def get_user_by_email_case_insensitive(email) do
          Queries.base()
          |> Queries.by_email_case_insensitive(email)
          |> Repo.one()
        end
      end

  ## Pattern Consistency

  Existing contexts follow this pattern:
  - ✅ Workspaces has Workspaces.Queries
  - ✅ Projects has Projects.Queries
  - ✅ Pages has Pages.Queries
  - ✅ Notes has Notes.Queries
  - ❌ Accounts has inline queries (inconsistent)

  ## Benefits of Query Objects

  - **Composability**: Chain query functions together
  - **Reusability**: Use same query logic in multiple contexts
  - **Testability**: Test query logic in isolation
  - **Consistency**: Uniform pattern across codebase
  - **Maintainability**: Changes to queries in one place
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      Context modules should extract Ecto queries to Query objects.

      Inline queries in contexts should be moved to dedicated Query modules
      for composability, reusability, and consistency.

      Pattern:
      - Context calls Queries module
      - Queries module builds queryable
      - Context calls Repo with queryable

      This ensures:
      - Consistent architecture across contexts
      - Reusable and composable queries
      - Better testability
      - Easier maintenance
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check context modules (not Queries, not web, not use_cases)
    if context_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  # Check if this is a context module file
  defp context_file?(source_file) do
    filename = source_file.filename

    # Context files are lib/jarga/context_name.ex
    String.contains?(filename, "lib/jarga/") and
      not String.contains?(filename, "lib/jarga_web/") and
      not String.contains?(filename, "/queries") and
      not String.contains?(filename, "/use_cases/") and
      not String.contains?(filename, "/policies/") and
      not String.contains?(filename, "/infrastructure/") and
      not String.contains?(filename, "/services/") and
      not String.ends_with?(filename, "_test.exs") and
      context_module_pattern?(filename)
  end

  # Context modules are typically lib/jarga/context_name.ex
  defp context_module_pattern?(filename) do
    case String.split(filename, "lib/jarga/") do
      [_, rest] ->
        parts = String.split(rest, "/")
        context_name = String.replace(rest, ".ex", "")

        # Single file at context level and is an actual context
        length(parts) == 1 and
          context_name in ["accounts", "workspaces", "projects", "pages", "notes"]

      _ ->
        false
    end
  end

  # Detect from(...) - Ecto query
  defp traverse({:from, meta, _args} = ast, issues, issue_meta) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "from",
         "inline Ecto query with from(...)"
       )
       | issues
     ]}
  end

  # Detect fragment() - SQL fragments
  defp traverse({:fragment, meta, _args} = ast, issues, issue_meta) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "fragment",
         "SQL fragment in context"
       )
       | issues
     ]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    context_name = extract_context_name(issue_meta)

    format_issue(
      issue_meta,
      message:
        "Context contains inline Ecto query (#{description}). " <>
          "Extract to Query object: #{context_name}.Queries. " <>
          "Query objects provide composability, reusability, and consistency. " <>
          "Follow pattern used by Workspaces, Projects, Pages, and Notes contexts (Clean Architecture).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end

  defp extract_context_name(issue_meta) do
    # IssueMeta has a source_file field
    filename =
      case issue_meta do
        %{source_file: %{filename: filename}} -> filename
        _ -> ""
      end

    filename
    |> String.split("lib/jarga/")
    |> List.last()
    |> String.replace(".ex", "")
    |> Macro.camelize()
  end
end
