defmodule Credo.Check.Custom.Architecture.NoBroadcastInTransaction do
  @moduledoc """
  Detects PubSub broadcasts inside database transaction blocks.

  ## Race Condition Prevention

  Broadcasting events inside a transaction creates race conditions where listeners
  may query the database before the transaction commits, seeing stale data.

  ## The Correct Pattern

  Always complete the transaction first, then broadcast based on the result.

  ## Examples

  ### Invalid - Broadcasting inside transaction:

      def execute(user_id, opts \\ []) do
        notifier = Keyword.get(opts, :notifier, PubSubNotifier)

        Repo.transact(fn ->
          user = Repo.get!(User, user_id)
          {:ok, updated} = Repo.update(changeset)

          # ❌ RACE CONDITION: Broadcast before commit
          notifier.broadcast_event(:user_updated, updated)

          {:ok, updated}
        end)
      end

  ### Valid - Broadcast after transaction commits:

      def execute(user_id, opts \\ []) do
        notifier = Keyword.get(opts, :notifier, PubSubNotifier)

        result = Repo.transact(fn ->
          user = Repo.get!(User, user_id)
          {:ok, updated} = Repo.update(changeset)
          {:ok, updated}
        end)

        # ✅ SAFE: Broadcast after transaction commits
        case result do
          {:ok, updated} ->
            notifier.broadcast_event(:user_updated, updated)
            {:ok, updated}

          error ->
            error
        end
      end

  ## What This Check Detects

  - `Phoenix.PubSub.broadcast/3` or `broadcast_from/4` inside `Repo.transaction/2` or `Repo.transact/1`
  - Function calls starting with `broadcast_` inside transaction blocks
  - Calls to `.broadcast_event/2` or similar notifier methods inside transactions
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: """
      PubSub broadcasts must happen AFTER database transactions commit.

      Broadcasting inside a transaction creates race conditions where listeners
      receive events for data that hasn't been committed yet.

      Pattern:
        result = Repo.transact(fn -> ... end)
        case result do
          {:ok, data} -> notifier.broadcast(...); {:ok, data}
          error -> error
        end

      See lib/jarga/notifications/application/use_cases/accept_workspace_invitation.ex
      for a correct example.
      """
    ]

  alias Credo.Code
  alias Credo.{SourceFile, IssueMeta}

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params) do
    issue_meta = IssueMeta.for(source_file, params)
    Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
  end

  # Match Repo.transaction(...) or Repo.transact(...)
  defp traverse(
         {{:., meta, [{:__aliases__, _, [:Repo]}, function_name]}, _,
          [transaction_body | _rest]} = ast,
         issues,
         issue_meta
       )
       when function_name in [:transaction, :transact] do
    # Check if there are any broadcasts inside the transaction body
    broadcast_issues = find_broadcasts_in_block(transaction_body, issue_meta, meta)

    {ast, broadcast_issues ++ issues}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  # Find broadcasts in the transaction body (which is an anonymous function)
  defp find_broadcasts_in_block({:fn, _, clauses}, issue_meta, transaction_meta) do
    Enum.flat_map(clauses, fn {:->, _, [_args, body]} ->
      find_broadcasts_in_ast(body, issue_meta, transaction_meta)
    end)
  end

  defp find_broadcasts_in_block(_other, _issue_meta, _transaction_meta), do: []

  # Recursively search AST for broadcast calls
  defp find_broadcasts_in_ast(ast, issue_meta, transaction_meta) do
    {_ast, issues} =
      Macro.prewalk(ast, [], fn node, acc ->
        case check_for_broadcast(node) do
          {:broadcast_found, meta, trigger} ->
            issue = issue_for(issue_meta, meta, trigger, transaction_meta)
            {node, [issue | acc]}

          :ok ->
            {node, acc}
        end
      end)

    issues
  end

  # Check if a node is a broadcast call
  defp check_for_broadcast(
         {{:., meta, [{:__aliases__, _, [:Phoenix, :PubSub]}, function_name]}, _, _}
       )
       when function_name in [:broadcast, :broadcast_from] do
    {:broadcast_found, meta, "Phoenix.PubSub.#{function_name}"}
  end

  # Check for function calls starting with "broadcast_"
  defp check_for_broadcast(
         {{:., meta, [_module_or_var, function_name]}, _, _}
       )
       when is_atom(function_name) do
    function_str = Atom.to_string(function_name)

    if String.starts_with?(function_str, "broadcast_") do
      {:broadcast_found, meta, function_str}
    else
      :ok
    end
  end

  # Check for local function calls starting with "broadcast_"
  defp check_for_broadcast({function_name, meta, args})
       when is_atom(function_name) and is_list(args) do
    function_str = Atom.to_string(function_name)

    if String.starts_with?(function_str, "broadcast_") do
      {:broadcast_found, meta, function_str}
    else
      :ok
    end
  end

  defp check_for_broadcast(_node), do: :ok

  defp issue_for(issue_meta, broadcast_meta, trigger, transaction_meta) do
    transaction_line = Keyword.get(transaction_meta, :line, 0)
    broadcast_line = Keyword.get(broadcast_meta, :line, 0)

    format_issue(
      issue_meta,
      message:
        "Found '#{trigger}' inside transaction (line #{transaction_line}). " <>
          "Broadcasts must happen AFTER transactions commit to avoid race conditions. " <>
          "Move the broadcast outside the Repo.transact/transaction block.",
      trigger: trigger,
      line_no: broadcast_line
    )
  end
end
