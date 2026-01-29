defmodule Credo.Check.Custom.Architecture.NoCrossContextPolicyAccess do
  @moduledoc """
  Detects direct access to Policy modules across context boundaries.

  ## Boundary Encapsulation Violation

  When one context needs functionality from another context, it should only
  use the public API (context module functions). Direct access to internal
  modules like Policies creates tight coupling.

  Per ARCHITECTURE.md lines 317-346:
  ```
  Cross-Context Communication:
  - When one context needs functionality from another, use the public API only
  - Never access internal modules (Queries, Policies) from other boundaries
  - Use context public APIs for cross-context communication
  ```

  Per ARCHITECTURE.md lines 289-315:
  ```
  Public APIs Only:
  - Cross-context communication only through exported functions
  - Compile-Time Enforcement: Boundary violations are caught during compilation
  ```

  ## Why This Creates Tight Coupling

  1. **Knowledge of internals**: Calling context knows about internal structure
  2. **Fragile**: Changes to policy implementation break dependent contexts
  3. **Boundary violation**: Bypasses context encapsulation
  4. **Hard to change**: Policy changes ripple across contexts

  ## Examples

  ### Invalid - Direct policy access across contexts:

      defmodule Jarga.Pages do
        # ❌ Directly importing and using Workspaces policy
        alias Jarga.Workspaces.Policies.PermissionsPolicy

        def create_page(user, workspace_id, attrs) do
          # ❌ Pages context knows about Workspaces internal policy structure
          if PermissionsPolicy.can?(member.role, :create_page) do
            # ...
          end
        end
      end

  ### Valid - Use context public API:

      defmodule Jarga.Workspaces do
        alias Jarga.Workspaces.Policies.PermissionsPolicy

        # ✅ Expose delegation method in public API
        def authorize_action(member_role, action, opts \\\\ []) do
          if PermissionsPolicy.can?(member_role, action, opts) do
            :ok
          else
            {:error, :forbidden}
          end
        end
      end

      defmodule Jarga.Pages do
        # ✅ Use Workspaces public API
        def create_page(user, workspace_id, attrs) do
          case Workspaces.authorize_action(member.role, :create_page) do
            :ok -> # ...
            {:error, :forbidden} -> {:error, :forbidden}
          end
        end
      end

  ## Benefits of Context Public APIs

  - **Encapsulation**: Internal implementation can change freely
  - **Loose coupling**: Contexts depend on interfaces, not implementations
  - **Clear boundaries**: Public API documents what's intended for external use
  - **Easier refactoring**: Changes isolated within context boundary
  - **Better testing**: Mock context functions, not internal policies

  ## When This Check Triggers

  This check detects when a context module:
  - Imports/aliases a Policy module from a different context
  - Calls a Policy module function from a different context

  Example patterns caught:
  - `alias Jarga.OtherContext.Policies.SomePolicy`
  - `OtherContext.Policies.SomePolicy.function()`
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: """
      Contexts should not directly access Policy modules from other contexts.

      Cross-context communication should go through public APIs only.
      Direct policy access creates tight coupling and violates boundary
      encapsulation.

      Pattern:
      - Add delegation method to context public API
      - Other contexts call delegation method
      - Internal policy remains encapsulated

      This ensures:
      - Loose coupling between contexts
      - Clear public API boundaries
      - Easier refactoring
      - Better encapsulation
      """
    ]

  alias Credo.Code
  alias Credo.SourceFile
  alias Credo.IssueMeta

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)

    # Only check context modules
    if context_file?(source_file) do
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta, source_file))
    else
      []
    end
  end

  # Check if this is a context module file
  defp context_file?(source_file) do
    filename = source_file.filename

    String.contains?(filename, "lib/jarga/") and
      not String.contains?(filename, "lib/jarga_web/") and
      not String.contains?(filename, "/policies/") and
      not String.contains?(filename, "/use_cases/") and
      not String.contains?(filename, "/infrastructure/") and
      not String.contains?(filename, "/services/") and
      not String.ends_with?(filename, "_test.exs")
  end

  # Detect alias OtherContext.Policies.SomePolicy
  defp traverse(
         {:alias, meta, [{:__aliases__, _, module_parts} | _]} = ast,
         issues,
         issue_meta,
         source_file
       ) do
    issues =
      if cross_context_policy_alias?(module_parts, source_file) do
        [
          issue_for(
            issue_meta,
            meta,
            format_module(module_parts),
            "aliasing policy from different context"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  # Detect OtherContext.Policies.SomePolicy.function() calls
  defp traverse(
         {{:., meta, [{:__aliases__, _, module_parts}, function]}, _, _args} = ast,
         issues,
         issue_meta,
         source_file
       ) do
    issues =
      if cross_context_policy_call?(module_parts, source_file) do
        [
          issue_for(
            issue_meta,
            meta,
            "#{format_module(module_parts)}.#{function}",
            "calling policy from different context"
          )
          | issues
        ]
      else
        issues
      end

    {ast, issues}
  end

  defp traverse(ast, issues, _issue_meta, _source_file) do
    {ast, issues}
  end

  # Check if this is aliasing a policy from a different context
  defp cross_context_policy_alias?(module_parts, source_file) do
    module_string = format_module(module_parts)

    # Check if it's a policy module
    String.contains?(module_string, ".Policies.") and
      # Check if it's from a different context
      different_context?(module_parts, source_file)
  end

  # Check if this is calling a policy from a different context
  defp cross_context_policy_call?(module_parts, source_file) do
    module_string = format_module(module_parts)

    # Check if it's a policy module
    String.contains?(module_string, ".Policies.") and
      # Check if it's from a different context
      different_context?(module_parts, source_file)
  end

  # Check if the module is from a different context
  defp different_context?(module_parts, source_file) do
    # Extract context from module path: Jarga.ContextName.Policies...
    module_context =
      case module_parts do
        [:Jarga, context | _] -> context
        _ -> nil
      end

    # Extract context from source file path
    file_context = extract_file_context(source_file.filename)

    module_context && file_context && module_context != file_context
  end

  # Extract context name from file path
  defp extract_file_context(filename) do
    case String.split(filename, "lib/jarga/") do
      [_, rest] ->
        rest
        |> String.split("/")
        |> List.first()
        |> case do
          name when name in ["accounts", "workspaces", "projects", "pages", "notes"] ->
            name |> Macro.camelize() |> String.to_atom()

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp format_module(module_parts) do
    Enum.join(module_parts, ".")
  end

  defp issue_for(issue_meta, meta, trigger, description) do
    format_issue(
      issue_meta,
      message:
        "Context accesses Policy from different context (#{description}). " <>
          "Use context public API instead of direct policy access. " <>
          "Add delegation method to the context module to encapsulate policy logic. " <>
          "Direct policy access creates tight coupling and violates boundary encapsulation (Clean Architecture).",
      trigger: trigger,
      line_no: Keyword.get(meta, :line, 0)
    )
  end
end
