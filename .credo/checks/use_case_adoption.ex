defmodule Jarga.Credo.Check.Architecture.UseCaseAdoption do
  @moduledoc """
  Detects complex orchestration logic in context modules that should be extracted to use cases.

  ## Clean Architecture Violation

  Context modules should have a thin public API that delegates to use cases for
  complex business operations. When context functions contain complex orchestration
  logic, they should be extracted to dedicated use case modules.

  Per ARCHITECTURE.md lines 489-544: "Use cases implement business operations by
  orchestrating domain policies and infrastructure."

  Per CLAUDE.md: "Use Cases Pattern: Create a behavior for standardized use case
  interface. Each use case implements a single business operation."

  ## Indicators of Missing Use Case

  This check flags context functions that contain:
  - `Ecto.Multi` operations (complex transactions)
  - `Repo.transaction` blocks with multiple operations
  - Complex `with` statements (5+ clauses indicating orchestration)

  ## Examples

  ### Invalid - Complex orchestration in context:

      defmodule Jarga.Pages do
        def create_page(user, workspace_id, attrs) do
          # ❌ Complex Multi transaction directly in context
          Multi.new()
          |> Multi.run(:verify_member, fn repo, _ ->
            verify_workspace_membership(repo, user, workspace_id)
          end)
          |> Multi.insert(:page, page_changeset(attrs))
          |> Multi.run(:note, fn repo, %{page: page} ->
            create_initial_note(repo, page)
          end)
          |> Multi.run(:component, fn repo, changes ->
            link_note_to_page(repo, changes)
          end)
          |> Repo.transaction()
        end
      end

  ### Valid - Extract to use case:

      defmodule Jarga.Pages do
        alias Jarga.Pages.UseCases.CreatePage

        # ✅ Thin context function delegating to use case
        def create_page(user, workspace_id, attrs) do
          CreatePage.execute(%{
            actor: user,
            workspace_id: workspace_id,
            attrs: attrs
          })
        end
      end

      defmodule Jarga.Pages.UseCases.CreatePage do
        @behaviour Jarga.Pages.UseCases.UseCase

        # ✅ Complex orchestration logic in dedicated use case
        def execute(params) do
          %{actor: actor, workspace_id: workspace_id, attrs: attrs} = params

          Multi.new()
          |> Multi.run(:verify_member, fn repo, _ ->
            verify_membership(repo, actor, workspace_id)
          end)
          |> Multi.insert(:page, page_changeset(attrs))
          |> Multi.run(:note, &create_initial_note/2)
          |> Multi.run(:component, &link_note_to_page/2)
          |> Repo.transaction()
        end
      end

  ### Invalid - Complex with chain in context:

      defmodule Jarga.Projects do
        def create_project(user, workspace_id, attrs) do
          # ❌ Complex orchestration with many steps
          with {:ok, member} <- get_workspace_member(user, workspace_id),
               :ok <- authorize_create_project(member.role),
               {:ok, slug} <- generate_unique_slug(attrs),
               {:ok, project} <- insert_project(attrs),
               {:ok, _notification} <- notify_workspace_members(project),
               {:ok, _activity} <- log_activity(project) do
            {:ok, project}
          end
        end
      end

  ### Valid - Simple delegation or simple operations:

      defmodule Jarga.Projects do
        # ✅ Simple operations don't need use cases
        def get_project(id), do: Repo.get(Project, id)
        def list_projects(workspace_id), do: Queries.by_workspace(workspace_id) |> Repo.all()

        # ✅ Complex operations delegate to use case
        def create_project(user, workspace_id, attrs) do
          CreateProject.execute(%{actor: user, workspace_id: workspace_id, attrs: attrs})
        end
      end

  ## Benefits of Use Cases

  Extracting complex logic to use cases provides:
  - **Single Responsibility**: Each use case handles one business operation
  - **Testability**: Use cases can be tested in isolation with mocked dependencies
  - **Reusability**: Use cases can be called from multiple interfaces (controllers, LiveViews, background jobs)
  - **Consistency**: Standardized interface across all business operations
  - **Dependency Injection**: Easy to inject test doubles for infrastructure
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    param_defaults: [with_clause_threshold: 5],
    explanations: [
      check: """
      Context modules should delegate complex business operations to use cases.

      When a context function contains complex orchestration logic like:
      - Ecto.Multi transactions
      - Multiple-step Repo.transaction blocks
      - Long with chains (default: 5+ clauses, configurable)

      This logic should be extracted to a dedicated use case module.

      Use cases provide:
      - Single Responsibility Principle compliance
      - Better testability with dependency injection
      - Consistent interface across business operations
      - Reusability from multiple entry points

      Context modules should have thin public APIs that delegate to use cases.
      """,
      params: [
        with_clause_threshold:
          "Minimum number of with clauses to trigger warning (default: 5)"
      ]
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check context modules (not web, not use_cases themselves)
    if context_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  # Check if this is a context module file
  defp context_file?(source_file) do
    filename = source_file.filename

    # Check if it's in lib/jarga/ (not lib/jarga_web/)
    # and not in use_cases/ subdirectory
    # and not a schema, query, policy, or repo file
    String.contains?(filename, "lib/jarga/") and
      not String.contains?(filename, "lib/jarga_web/") and
      not String.contains?(filename, "/use_cases/") and
      not String.contains?(filename, "/queries") and
      not String.contains?(filename, "/policies/") and
      not String.contains?(filename, "/infrastructure/") and
      not String.contains?(filename, "/domain/") and
      not String.ends_with?(filename, "_test.exs") and
      # Context files are typically at the root level like lib/jarga/pages.ex
      # Not nested deeply like lib/jarga/pages/page.ex
      context_module_pattern?(filename)
  end

  # Context modules are typically lib/jarga/context_name.ex
  # Not lib/jarga/context_name/some_schema.ex
  defp context_module_pattern?(filename) do
    # Extract path after lib/jarga/
    case String.split(filename, "lib/jarga/") do
      [_, rest] ->
        # Check if it's just "context.ex" or has one level "accounts/user.ex"
        # Context modules: pages.ex, projects.ex, accounts.ex
        # We want to check the main context files
        parts = String.split(rest, "/")
        # Context file if it's lib/jarga/name.ex (only one part)
        length(parts) == 1

      _ ->
        false
    end
  end

  # Detect Multi.new() - indicates complex transaction
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Multi]}, :new]}, _, []} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "Multi.new()",
         "Ecto.Multi transaction",
         "CreateOperation or UpdateOperation"
       )
       | issues
     ]}
  end

  # Detect Ecto.Multi.new()
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Ecto, :Multi]}, :new]}, _, []} = ast,
         issues,
         issue_meta
       ) do
    {ast,
     [
       issue_for(
         issue_meta,
         meta,
         "Multi.new()",
         "Ecto.Multi transaction",
         "CreateOperation or UpdateOperation"
       )
       | issues
     ]}
  end

  # Detect Repo.transaction(fn -> ... end) - complex transaction block
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, :transaction]}, _, [{:fn, _, _}]} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if is_repo_module?(module_parts) do
        [
          issue_for(
            issue_meta,
            meta,
            "Repo.transaction",
            "transaction block with multiple operations",
            "CreateOperation or UpdateOperation"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect complex with statements (configurable threshold, default 5)
  defp traverse({:with, meta, clauses} = ast, issues, issue_meta) do
    # Count <- clauses (actual operations, not the do block)
    operation_clauses = Enum.count(clauses, fn
      {:<-, _, _} -> true
      _ -> false
    end)

    threshold = IssueMeta.params(issue_meta) |> Keyword.get(:with_clause_threshold, 5)

    issues =
      if operation_clauses >= threshold do
        [
          issue_for(
            issue_meta,
            meta,
            "with (#{operation_clauses} clauses)",
            "complex with statement with #{operation_clauses} operations",
            "CreateOperation or UpdateOperation"
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

  defp issue_for(issue_meta, meta, trigger, description, suggested_name) do
    format_issue(
      issue_meta,
      message:
        "Complex orchestration logic detected (#{description}). " <>
          "Extract to use case pattern. Suggestion: [Context].UseCases.#{suggested_name}. " <>
          "Use cases provide better testability, SRP compliance, and consistent interfaces. " <>
          "Keep context functions thin - delegate to use cases for complex operations (Clean Architecture).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end

  # Check if module_parts represent a Repo module
  defp is_repo_module?(module_parts) do
    module_parts == [:Repo] or List.last(module_parts) == :Repo
  end
end
