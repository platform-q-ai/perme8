defmodule Credo.Check.Custom.Architecture.NoCrossContextSchemaAccess do
  @moduledoc """
  Detects direct access to Schema modules across context boundaries.

  ## Boundary Encapsulation Violation

  When one context needs data from another context, it should use the public
  context API, not access schemas directly via Repo calls.

  Per ARCHITECTURE.md:
  ```
  Cross-Context Communication:
  - When one context needs functionality from another, use the public API only
  - Never access internal modules (Queries, Policies, Schemas) from other boundaries
  - Use context public APIs for cross-context communication
  ```

  Per CLAUDE.md:
  ```
  Context Independence: Each context (Accounts, Workspaces, Projects) is an
  independent boundary. Public APIs Only: Cross-context communication only
  through exported functions.
  ```

  ## Why Direct Schema Access Creates Problems

  1. **Bypasses encapsulation**: Other contexts can't control how their data is accessed
  2. **Tight coupling**: Changes to schema structure break dependent contexts
  3. **No authorization**: Direct Repo access bypasses context-level authorization
  4. **Fragile**: Schema changes ripple across contexts
  5. **Boundary violation**: Defeats the purpose of context boundaries

  ## Examples

  ### Invalid - Direct schema access across contexts:

      defmodule Jarga.Pages do
        alias Jarga.Repo

        # ❌ Directly accessing Notes schema from Pages context
        def get_page_note(page) do
          note_id = get_note_id(page)
          Repo.get!(Jarga.Notes.Note, note_id)
        end
      end

  ### Valid - Use context public API:

      defmodule Jarga.Notes do
        # ✅ Public API function
        def get_note_by_id(note_id) do
          Repo.get(Note, note_id)
        end
      end

      defmodule Jarga.Pages do
        # ✅ Use Notes public API
        def get_page_note(page) do
          note_id = get_note_id(page)
          Notes.get_note_by_id(note_id)
        end
      end

  ## When Repository Layer is Appropriate

  If you need to access data from multiple contexts, create a repository in
  your Infrastructure layer:

      defmodule Jarga.Pages.Infrastructure.ComponentRepository do
        # ✅ Infrastructure layer can access schemas
        def get_component("note", id), do: Repo.get(Jarga.Notes.Note, id)
        def get_component("task", id), do: Repo.get(Jarga.Pages.Task, id)
      end

  ## Benefits of Context Public APIs

  - **Encapsulation**: Internal schema structure can change freely
  - **Authorization**: Context can enforce access control
  - **Loose coupling**: Contexts depend on interfaces, not schemas
  - **Clear boundaries**: Public API documents external interface
  - **Better testing**: Mock context functions, not Repo calls

  ## Detected Patterns

  This check detects when a context module:
  - Calls `Repo.get/get!/get_by/etc` with a schema from a different context
  - Uses schemas like `Notes.Note`, `Accounts.User`, `Projects.Project`
    from a different context in Repo calls

  Example patterns caught:
  - `Repo.get!(Jarga.Notes.Note, id)` in Pages context
  - `Repo.get_by(Accounts.User, email: email)` in Projects context
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      Contexts should not directly access schemas from other contexts via Repo.

      Cross-context data access should go through public context APIs.
      Direct schema access creates tight coupling and violates boundary
      encapsulation.

      Pattern:
      - Add public API function to source context
      - Other contexts call that public function
      - Direct Repo access stays within context boundary

      This ensures:
      - Loose coupling between contexts
      - Authorization at context boundary
      - Clear public API boundaries
      - Easier refactoring
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check context modules (not web, not infrastructure)
    if context_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta, source_file))
    else
      []
    end
  end

  # Check if this is a context module file (not web, not infrastructure)
  defp context_file?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "lib/jarga/") and
      not String.contains?(filename, "lib/jarga_web/") and
      not String.contains?(filename, "/infrastructure/") and
      not String.contains?(filename, "/services/") and
      not String.contains?(filename, "/queries") and
      not String.contains?(filename, "/policies/") and
      not String.contains?(filename, "/use_cases/") and
      not String.contains?(filename, "/domain/") and
      not String.ends_with?(filename, "_test.exs") and
      context_module_pattern?(filename)
  end

  # Context modules are typically lib/jarga/context_name.ex
  defp context_module_pattern?(filename) do
    case String.split(filename, "lib/jarga/") do
      [_, rest] ->
        parts = String.split(rest, "/")
        # Context file if it's lib/jarga/name.ex (only one part)
        length(parts) == 1

      _ ->
        false
    end
  end

  # Detect Repo.get/get!/get_by/etc with cross-context schema
  defp traverse(
         {{:., meta, [{:__aliases__, _, repo_parts}, repo_function]}, _,
          [{:__aliases__, _, schema_parts} | _]} = ast,
         issues,
         issue_meta,
         source_file
       ) do
    issues =
      if repo_function?(repo_parts, repo_function) and
           cross_context_schema?(schema_parts, source_file) do
        [
          issue_for(
            issue_meta,
            meta,
            "Repo.#{repo_function}(#{format_module(schema_parts)}, ...)",
            "accessing #{format_module(schema_parts)} from different context via Repo.#{repo_function}",
            extract_schema_context(schema_parts)
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Also detect when schema is referenced via alias (e.g., Note instead of Jarga.Notes.Note)
  defp traverse(
         {{:., meta, [{:__aliases__, _, repo_parts}, repo_function]}, _, [schema_alias | _]} =
           ast,
         issues,
         issue_meta,
         source_file
       )
       when is_atom(schema_alias) do
    issues =
      if repo_function?(repo_parts, repo_function) do
        # Check if this alias might be a cross-context schema
        # We'll be conservative and check based on common schema names
        case check_aliased_schema(schema_alias, source_file) do
          {:cross_context, context_name} ->
            [
              issue_for(
                issue_meta,
                meta,
                "Repo.#{repo_function}(#{schema_alias}, ...)",
                "potentially accessing #{schema_alias} from #{context_name} context via Repo.#{repo_function}",
                context_name
              )
              | issues
            ]

          :same_context ->
            issues

          :unknown ->
            # Don't report if we can't determine
            issues
        end
      else
        issues
      end

    {ast, issues}
  end

  defp traverse(ast, issues, _issue_meta, _source_file) do
    {ast, issues}
  end

  # Check if this is a Repo data access function
  defp repo_function?(module_parts, function) do
    List.last(module_parts) == :Repo and
      function in [
        :get,
        :get!,
        :get_by,
        :get_by!,
        :one,
        :one!,
        :preload
      ]
  end

  # Check if schema is from a different context
  defp cross_context_schema?(schema_parts, source_file) do
    case extract_schema_context(schema_parts) do
      nil ->
        false

      schema_context ->
        file_context = extract_file_context(source_file.filename)
        file_context && schema_context != file_context
    end
  end

  # Extract context name from schema module path: Jarga.ContextName.Schema
  defp extract_schema_context(module_parts) do
    case module_parts do
      [:Jarga, context, _schema] when is_atom(context) ->
        # Convert to lowercase string
        context |> Atom.to_string() |> String.downcase()

      _ ->
        nil
    end
  end

  # Extract context name from file path
  defp extract_file_context(filename) do
    case String.split(filename, "lib/jarga/") do
      [_, rest] ->
        rest
        |> String.split("/")
        |> List.first()
        |> String.replace(".ex", "")

      _ ->
        nil
    end
  end

  # Check if an aliased schema (like Note) is from a different context
  defp check_aliased_schema(schema_alias, source_file) do
    file_context = extract_file_context(source_file.filename)
    schema_name = Atom.to_string(schema_alias)

    # Map common schema names to their contexts
    schema_to_context = %{
      "User" => "accounts",
      "Workspace" => "workspaces",
      "WorkspaceMember" => "workspaces",
      "Project" => "projects",
      "Page" => "pages",
      "PageComponent" => "pages",
      "Note" => "notes"
    }

    case Map.get(schema_to_context, schema_name) do
      nil ->
        :unknown

      schema_context ->
        if file_context && schema_context != file_context do
          {:cross_context, schema_context}
        else
          :same_context
        end
    end
  end

  defp format_module(module_parts) do
    Enum.join(module_parts, ".")
  end

  defp issue_for(issue_meta, meta, trigger, description, context_name) do
    format_issue(
      issue_meta,
      message:
        "Context directly accesses schema from different context (#{description}). " <>
          "Use #{String.capitalize(context_name)}.get_*() public API instead. " <>
          "Direct schema access creates tight coupling and bypasses authorization. " <>
          "Cross-context communication must go through public APIs (Clean Architecture).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
