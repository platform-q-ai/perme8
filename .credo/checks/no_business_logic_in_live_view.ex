defmodule Jarga.Credo.Check.Architecture.NoBusinessLogicInLiveView do
  @moduledoc """
  Detects business logic patterns in LiveView modules.

  ## Clean Architecture Violation

  LiveView modules are part of the interface/presentation layer and should
  contain only UI state management and event handling. Business logic should
  live in context modules or use cases.

  ## Patterns that indicate business logic:

  - Multi.new() or Multi.run() (Ecto.Multi transactions)
  - Complex with statements with multiple steps
  - Direct changeset operations beyond simple validation
  - Complex calculations or algorithms

  ## Examples

  ### Invalid - Business logic in LiveView:

      defmodule JargaWeb.ItemLive do
        def handle_event("create", params, socket) do
          Multi.new()
          |> Multi.insert(:item, changeset)
          |> Multi.run(:notify, fn ... end)
          |> Repo.transaction()  # ❌ Business logic in LiveView
        end
      end

  ### Valid - Delegate to context:

      defmodule JargaWeb.ItemLive do
        def handle_event("create", params, socket) do
          case Items.create_item(params) do  # ✅ Correct
            {:ok, item} -> {:noreply, assign(socket, :item, item)}
            {:error, changeset} -> {:noreply, assign(socket, :changeset, changeset)}
          end
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      LiveView modules should not contain business logic.

      Business logic should be in context modules or use case modules.
      LiveView callbacks should only handle UI state and delegate to contexts.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check LiveView files
    if live_view?(source_file) do
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  defp live_view?(source_file) do
    String.contains?(source_file.filename, "/jarga_web/live/") or
      String.contains?(source_file.filename, "/live_view/")
  end

  # Check for Ecto.Multi usage
  defp traverse(
         {{:., _meta1, [{:__aliases__, _meta2, [:Ecto, :Multi]}, :new]}, _meta3, _args} = ast,
         issues,
         issue_meta
       ) do
    {ast, [issue_for(issue_meta, ast, "Ecto.Multi transactions") | issues]}
  end

  defp traverse(
         {{:., _meta1, [{:__aliases__, _meta2, [:Multi]}, :new]}, _meta3, _args} = ast,
         issues,
         issue_meta
       ) do
    {ast, [issue_for(issue_meta, ast, "Ecto.Multi transactions") | issues]}
  end

  # Check for complex with statements (more than 5 clauses likely indicates orchestration logic)
  # Note: Up to 5 clauses is acceptable for loading related resources in mount/3
  defp traverse({:with, _meta, clauses} = ast, issues, issue_meta) when length(clauses) > 5 do
    {ast, [issue_for(issue_meta, ast, "Complex with statement") | issues]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, ast, trigger) do
    format_issue(
      issue_meta,
      message:
        "LiveView contains business logic (#{trigger}). Delegate to context modules or use cases instead.",
      trigger: trigger,
      line_no: Keyword.get(elem(ast, 1), :line)
    )
  end
end
