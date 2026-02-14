defmodule Credo.Check.Custom.Architecture.PoliciesInApplicationLayer do
  @moduledoc """
  Ensures all policy modules are located in `application/policies/` subdirectory.

  This check enforces Clean Architecture by ensuring policies (authorization logic) are:
  1. Located in the application layer (not infrastructure or domain)
  2. Clearly separated from other application concerns
  3. Easy to identify as authorization/business rules

  ## Current Violations

  Policies at wrong locations:
  - `lib/jarga/agents/policies/` → Should be `lib/jarga/agents/application/policies/`

  ## Expected Structure

      lib/jarga/{context}/
      └── application/
          └── policies/
              ├── {policy}.ex
              └── ...

  ## Configuration

      {Credo.Check.Custom.Architecture.PoliciesInApplicationLayer, []}

  """

  use Credo.Check,
    base_priority: :high,
    category: :design,
    explanations: [
      check: """
      Policies (authorization logic) should be in application/policies/ subdirectory.

      Policies contain business rules for authorization and should be
      part of the application layer, not infrastructure or domain.
      """
    ]

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    file_path = source_file.filename

    # Only check policy modules
    if is_policy_module?(file_path) do
      check_policy_location(file_path, issue_meta)
    else
      []
    end
  end

  # Check if this is a policy module
  defp is_policy_module?(file_path) do
    # Must be in lib/jarga/{context}/policies/ or lib/jarga/{context}/application/policies/
    # Policy files typically end with _policy.ex
    (String.match?(file_path, ~r|lib/jarga/[^/]+/.*policies/[^/]+\.ex$|) or
       String.match?(file_path, ~r|lib/jarga/[^/]+/[^/]+_policy\.ex$|)) and
      not String.contains?(file_path, "test/") and
      not String.contains?(file_path, "jarga_web")
  end

  # Verify policy is in application/policies/ or domain/policies/ subdirectory
  defp check_policy_location(file_path, issue_meta) do
    cond do
      # ✅ Correct location: application/policies/
      String.match?(file_path, ~r|/application/policies/[^/]+\.ex$|) ->
        []

      # ✅ Correct location: domain/policies/ (pure business rules, no I/O)
      String.match?(file_path, ~r|/domain/policies/[^/]+\.ex$|) ->
        []

      # ❌ VIOLATION: Policy at wrong location (e.g., lib/jarga/agents/policies/)
      String.match?(file_path, ~r|lib/jarga/[^/]+/policies/[^/]+\.ex$|) ->
        module_name = extract_module_name(file_path)
        correct_path = get_correct_path(file_path)

        [
          create_issue(
            issue_meta,
            module_name,
            "Policy not in application layer",
            correct_path,
            1
          )
        ]

      # ❌ VIOLATION: Policy at context root
      String.match?(file_path, ~r|lib/jarga/[^/]+/[^/]+_policy\.ex$|) ->
        module_name = extract_module_name(file_path)
        correct_path = get_correct_path(file_path)

        [
          create_issue(
            issue_meta,
            module_name,
            "Policy at context root (should be in application/policies/)",
            correct_path,
            1
          )
        ]

      true ->
        []
    end
  end

  # Generate correct path
  defp get_correct_path(file_path) do
    cond do
      # lib/jarga/agents/policies/agent_policy.ex 
      # → lib/jarga/agents/application/policies/agent_policy.ex
      String.match?(file_path, ~r|lib/jarga/[^/]+/policies/|) ->
        String.replace(file_path, ~r|(lib/jarga/[^/]+)/policies/|, "\\1/application/policies/")

      # lib/jarga/agents/agent_policy.ex
      # → lib/jarga/agents/application/policies/agent_policy.ex
      String.match?(file_path, ~r|lib/jarga/[^/]+/[^/]+_policy\.ex$|) ->
        String.replace(
          file_path,
          ~r|(lib/jarga/[^/]+)/([^/]+_policy\.ex)$|,
          "\\1/application/policies/\\2"
        )

      true ->
        file_name = Path.basename(file_path)
        context = extract_context(file_path)
        "lib/jarga/#{context}/application/policies/#{file_name}"
    end
  end

  # Extract module name from file path
  defp extract_module_name(file_path) do
    case Regex.run(~r|lib/jarga/([^/]+)(?:/.+)?/(?:policies/)?([^/]+)\.ex$|, file_path) do
      [_, context, file_name] ->
        module_parts = [String.capitalize(context), "Policies", Macro.camelize(file_name)]
        "Jarga.#{Enum.join(module_parts, ".")}"

      _ ->
        "UnknownModule"
    end
  end

  # Extract context name from file path
  defp extract_context(file_path) do
    case Regex.run(~r|lib/jarga/([^/]+)/|, file_path) do
      [_, context] -> context
      _ -> "unknown"
    end
  end

  # Create Credo issue
  defp create_issue(issue_meta, module_name, trigger, correct_path, line_no) do
    format_issue(
      issue_meta,
      message:
        "Policy `#{module_name}` should be in application/policies/ subdirectory.\n" <>
          "  Policies are application layer concerns (authorization/business rules).\n" <>
          "  Move to: #{correct_path}",
      trigger: trigger,
      line_no: line_no
    )
  end
end
