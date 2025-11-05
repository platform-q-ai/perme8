defmodule Jarga.Credo.Check.Architecture.MissingQueriesModule do
  @moduledoc """
  Detects context modules that are missing a corresponding Queries module.

  ## Architectural Consistency Violation

  All Phoenix contexts should follow a consistent pattern for organizing
  database queries. The established pattern in this codebase is to use
  dedicated Query object modules.

  Per ARCHITECTURE.md lines 365-398:
  ```
  Query Objects:
  - Extract complex queries into dedicated query modules
  - Keep repositories thin by delegating to query objects
  - Make queries composable and reusable
  - Organize queries by domain entity
  ```

  Per CLAUDE.md:
  ```
  Query Objects:
  - Extract complex queries into dedicated query modules
  - Make queries composable and reusable
  - Query modules return Ecto queryables, not results
  ```

  ## Pattern Consistency

  Current contexts in the codebase:
  - ✅ Workspaces has Workspaces.Queries
  - ✅ Projects has Projects.Queries
  - ✅ Pages has Pages.Queries
  - ✅ Notes has Notes.Queries
  - ❌ Accounts missing Accounts.Queries (inconsistent)

  ## Why Query Modules Matter

  1. **Composability**: Build complex queries by chaining simple query functions
  2. **Reusability**: Use same query logic across multiple context functions
  3. **Testability**: Test query logic independently from business logic
  4. **Consistency**: Uniform pattern across all contexts
  5. **Maintainability**: Centralized query logic, easy to update

  ## Examples

  ### Missing - Context without Queries module:

      # File: lib/jarga/accounts.ex exists
      # File: lib/jarga/accounts/queries.ex MISSING ❌

      defmodule Jarga.Accounts do
        import Ecto.Query

        # Inline queries scattered throughout context
        def get_user_by_email(email) do
          from(u in User, where: u.email == ^email)
          |> Repo.one()
        end

        def list_active_users do
          from(u in User, where: u.active == true)
          |> Repo.all()
        end
      end

  ### Good - Context with Queries module:

      # File: lib/jarga/accounts.ex
      # File: lib/jarga/accounts/queries.ex ✅

      defmodule Jarga.Accounts.Queries do
        import Ecto.Query
        alias Jarga.Accounts.User

        def base, do: from(u in User)

        def by_email(query, email) do
          where(query, [u], u.email == ^email)
        end

        def active(query) do
          where(query, [u], u.active == true)
        end
      end

      defmodule Jarga.Accounts do
        alias Jarga.Accounts.Queries

        def get_user_by_email(email) do
          Queries.base()
          |> Queries.by_email(email)
          |> Repo.one()
        end

        def list_active_users do
          Queries.base()
          |> Queries.active()
          |> Repo.all()
        end
      end

  ## Query Module Structure

  A Queries module should:
  - Return Ecto.Queryable (not execute queries)
  - Provide composable query functions
  - Follow pattern: `def function_name(query, params)`
  - Include base query: `def base, do: from(schema in Schema)`

  ## Benefits

  - **Consistent**: Same pattern across all contexts
  - **Composable**: `Queries.base() |> Queries.filter1() |> Queries.filter2()`
  - **Testable**: Test queries without database
  - **Reusable**: One query, many uses
  - **Maintainable**: Query changes in one place
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      All context modules should have a corresponding Queries module.

      The codebase follows a pattern where each context has a Queries
      module for organizing database queries. This ensures:

      - Consistent architecture across contexts
      - Composable and reusable queries
      - Better separation of concerns
      - Easier testing and maintenance

      If a context exists (e.g., Accounts), there should be a
      corresponding Queries module (e.g., Accounts.Queries).
      """
    ]

  alias Credo.SourceFile

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    # Only check main context files
    if main_context_file?(source_file) and not has_queries_module?(source_file) do
      [create_issue(source_file)]
    else
      []
    end
  end

  # Check if this is a main context file (e.g., lib/jarga/accounts.ex)
  defp main_context_file?(source_file) do
    filename = source_file.filename

    # Main context files are lib/jarga/context_name.ex
    String.contains?(filename, "lib/jarga/") and
      not String.contains?(filename, "lib/jarga_web/") and
      not String.ends_with?(filename, "_test.exs") and
      context_module_pattern?(filename)
  end

  # Context modules are lib/jarga/context_name.ex (single level)
  defp context_module_pattern?(filename) do
    case String.split(filename, "lib/jarga/") do
      [_, rest] ->
        parts = String.split(rest, "/")
        context_name = String.replace(rest, ".ex", "")

        # Single file at context level, not nested
        length(parts) == 1 and
          # Only check actual context modules
          context_name in ["accounts", "workspaces", "projects", "pages", "notes"]

      _ ->
        false
    end
  end

  # Check if a Queries module exists for this context
  defp has_queries_module?(source_file) do
    queries_path = source_to_queries_path(source_file.filename)
    File.exists?(queries_path)
  end

  # Convert context path to expected queries path
  defp source_to_queries_path(source_path) do
    # lib/jarga/accounts.ex -> lib/jarga/accounts/queries.ex
    source_path
    |> String.replace(".ex", "/queries.ex")
  end

  # Create an issue for missing Queries module
  defp create_issue(source_file) do
    source_path = source_file.filename
    queries_path = source_to_queries_path(source_path)
    context_name = extract_context_name(source_path)

    %Credo.Issue{
      check: __MODULE__,
      category: :warning,
      priority: :normal,
      message:
        "Context missing Queries module. " <>
          "Create: #{queries_path}. " <>
          "All contexts should have a Queries module for consistency. " <>
          "Workspaces, Projects, Pages, and Notes all follow this pattern. " <>
          "Query modules provide composability, reusability, and better architecture.",
      filename: source_path,
      line_no: 1,
      trigger: context_name,
      column: nil,
      scope: nil
    }
  end

  # Extract context name from file path
  defp extract_context_name(source_path) do
    source_path
    |> String.split("/")
    |> List.last()
    |> String.replace(".ex", "")
    |> Macro.camelize()
  end
end
