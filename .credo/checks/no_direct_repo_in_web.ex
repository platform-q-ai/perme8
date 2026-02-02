defmodule Credo.Check.Custom.Architecture.NoDirectRepoInWeb do
  @moduledoc """
  Prevents direct use of Repo in the Web layer (JargaWeb).

  ## Clean Architecture Violation

  The web layer (interface adapters) should not directly access infrastructure
  (database repositories). Instead, it should delegate to context modules.

  ## Examples

  ### Invalid - Direct Repo usage in LiveView:

      defmodule JargaWeb.SomeLive do
        alias Jarga.Repo

        def handle_event("load", _params, socket) do
          items = Repo.all(Item)  # ❌ Violates Clean Architecture
          {:noreply, assign(socket, :items, items)}
        end
      end

  ### Valid - Delegate to context:

      defmodule JargaWeb.SomeLive do
        alias Jarga.Items

        def handle_event("load", _params, socket) do
          items = Items.list_items()  # ✅ Correct
          {:noreply, assign(socket, :items, items)}
        end
      end
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Web layer modules should not directly use Repo.

      The web layer (controllers, LiveViews, channels) is the interface adapter
      layer in Clean Architecture. It should not directly access infrastructure
      like database repositories.

      Instead, delegate to context modules which handle business logic and
      data access.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check files in JargaWeb
    if String.contains?(source_file.filename, "/jarga_web/") do
      Credo.Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    else
      []
    end
  end

  # Check for alias Jarga.Repo
  defp traverse({:alias, _meta, [{:__aliases__, _, module_parts}]} = ast, issues, issue_meta) do
    issues =
      if ends_with_repo?(module_parts) do
        [issue_for(issue_meta, ast) | issues]
      else
        issues
      end

    {ast, issues}
  end

  # Check for Repo.function_call()
  defp traverse(
         {{:., _meta1, [{:__aliases__, _meta2, module_parts}, _function]}, _meta3, _args} = ast,
         issues,
         issue_meta
       ) do
    issues =
      if ends_with_repo?(module_parts) do
        [issue_for(issue_meta, ast) | issues]
      else
        issues
      end

    {ast, issues}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp ends_with_repo?(module_parts) when is_list(module_parts) do
    List.last(module_parts) == :Repo
  end

  defp issue_for(issue_meta, ast) do
    format_issue(
      issue_meta,
      message:
        "Web layer should not directly use Repo. Delegate to context modules instead (Clean Architecture).",
      trigger: "Repo",
      line_no: Keyword.get(elem(ast, 1), :line)
    )
  end
end
