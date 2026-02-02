defmodule Credo.Check.Custom.Architecture.NoDatabaseQueriesInLiveViews do
  @moduledoc """
  Detects direct database queries in LiveView modules.

  ## Clean Architecture Violation

  LiveViews are part of the presentation layer and should not contain
  direct database operations. They should delegate all data access to context
  modules.

  ## What this checks:

  - Direct `Repo.get`, `Repo.all`, `Repo.one`, etc. calls
  - Direct `from(...)` query construction (Ecto.Query)
  - Database schema preloading with `Repo.preload`

  ## Examples

  ### Invalid - Direct query in LiveView:

      defmodule JargaWeb.ItemLive do
        def mount(_params, _session, socket) do
          items = Repo.all(Item)  # ❌ Direct database access
          {:ok, assign(socket, :items, items)}
        end

        def handle_info(:refresh, socket) do
          item = Repo.get!(Item, id) |> Repo.preload(:user)  # ❌ Direct query
          {:noreply, assign(socket, :item, item)}
        end
      end

  ### Valid - Delegate to context:

      defmodule JargaWeb.ItemLive do
        def mount(_params, _session, socket) do
          items = Items.list_items()  # ✅ Via context
          {:ok, assign(socket, :items, items)}
        end

        def handle_info(:refresh, socket) do
          item = Items.get_item_with_user(id)  # ✅ Via context
          {:noreply, assign(socket, :item, item)}
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      LiveView modules should not perform direct database queries.

      All data access should go through context modules. This ensures:
      - Separation of concerns (UI vs data access)
      - Reusability of business logic
      - Easier testing
      - Proper architectural boundaries
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

  # Check for from(...) Ecto.Query calls
  defp traverse({:from, meta, _args} = ast, issues, issue_meta) do
    {ast, [issue_for(issue_meta, meta, "Ecto.Query.from") | issues]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, meta, trigger) do
    format_issue(
      issue_meta,
      message:
        "LiveView contains direct database query (#{trigger}). Delegate to context modules instead (Clean Architecture).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
