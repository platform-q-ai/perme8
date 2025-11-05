defmodule Jarga.Credo.Check.Architecture.NoInfrastructureInPolicies do
  @moduledoc """
  Detects infrastructure dependencies in Policy modules.

  ## Clean Architecture Violation

  Policy modules should contain pure domain logic with zero external dependencies.
  They should not contain:
  - Database queries (Repo.all, Repo.one, etc.)
  - Ecto.Query operations (from, join, where, etc.)
  - External API calls
  - File I/O
  - Any side effects

  According to ARCHITECTURE.md lines 208-219 and CLAUDE.md, domain policies must be
  pure business rules without infrastructure dependencies.

  ## Examples

  ### Invalid - Infrastructure in Policy:

      defmodule Jarga.Projects.Policies.Authorization do
        alias Jarga.Repo

        def verify_project_access(user, project_id) do
          case Queries.for_user_by_id(user, project_id) |> Repo.one() do
            nil -> {:error, :not_found}  # ❌ Database query in policy
            project -> {:ok, project}
          end
        end
      end

  ### Valid - Pure domain policy:

      defmodule Jarga.Projects.Policies.AccessPolicy do
        def can_view_project?(:member), do: true
        def can_view_project?(:guest), do: false  # ✅ Pure logic

        def can_edit_project?(:owner, _project), do: true
        def can_edit_project?(:member, project) do
          # Pure business rule based on data
          project.allow_member_edits
        end
      end

  ### Valid - Infrastructure in separate module:

      defmodule Jarga.Projects.Infrastructure.AuthorizationRepository do
        alias Jarga.Repo

        def find_project_for_user(user, project_id) do
          Queries.for_user_by_id(user, project_id) |> Repo.one()
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Policy modules should contain only pure domain logic.

      Domain policies are pure business rules that should have zero infrastructure
      dependencies. This ensures:
      - Fast unit tests (no I/O)
      - Easy to understand business rules
      - Testable without database setup
      - True separation of concerns

      If you need to query the database for authorization, create a separate
      module in the Infrastructure layer (e.g., *Repository or *Queries).
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check files in .Policies. modules
    if policy_module?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp policy_module?(source_file) do
    String.contains?(source_file.filename, "/policies/") and
      String.ends_with?(source_file.filename, ".ex")
  end

  # Check for alias Jarga.Repo
  defp traverse({:alias, meta, [{:__aliases__, _, module_parts}]} = ast, issues, issue_meta) do
    issues =
      cond do
        ends_with_repo?(module_parts) ->
          [issue_for(issue_meta, meta, "Repo", "alias Jarga.Repo") | issues]

        contains_queries?(module_parts) ->
          [issue_for(issue_meta, meta, "Queries", "alias ...Queries") | issues]

        true ->
          issues
      end

    {ast, issues}
  end

  # Check for Repo.function_call()
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta
       ) do
    issues =
      cond do
        ends_with_repo?(module_parts) ->
          [issue_for(issue_meta, meta, "Repo.#{function}", "Repo.#{function}()") | issues]

        contains_queries?(module_parts) ->
          [issue_for(issue_meta, meta, "Queries.#{function}", "Queries.#{function}()") | issues]

        true ->
          issues
      end

    {ast, issues}
  end

  # Check for import Ecto.Query
  defp traverse({:import, meta, [{:__aliases__, _, [:Ecto, :Query]}]} = ast, issues, issue_meta) do
    {ast, [issue_for(issue_meta, meta, "Ecto.Query", "import Ecto.Query") | issues]}
  end

  # Check for from(...) Ecto.Query calls
  defp traverse({:from, meta, _args} = ast, issues, issue_meta) do
    {ast, [issue_for(issue_meta, meta, "from", "from(...) database query") | issues]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp ends_with_repo?(module_parts) when is_list(module_parts) do
    List.last(module_parts) == :Repo
  end

  defp contains_queries?(module_parts) when is_list(module_parts) do
    :Queries in module_parts
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Policy module contains infrastructure dependency (#{description}). " <>
          "Domain policies must be pure business logic with zero external dependencies. " <>
          "Move database queries to Infrastructure layer (Repository/Queries modules).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
