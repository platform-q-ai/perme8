defmodule Agents.Sessions.Domain.Policies.SdkEventTypes do
  @moduledoc """
  Classifies all 32 OpenCode SDK event types as either "handled by Session"
  or "not relevant to Session".

  ## Handled (17 events)
  Events that drive Session lifecycle state transitions, domain event emissions,
  or tracking field updates.

  ## Not Relevant (15 events)
  - `installation.*` -- system-level, not session-specific
  - `lsp.*` -- LSP infrastructure, not session lifecycle
  - `todo.updated` -- informational only (P2)
  - `command.executed` -- UI/TUI concern
  - `vcs.branch.updated` -- informational only (P2)
  - `tui.*` -- TUI rendering/interaction concerns
  - `pty.*` -- terminal management, separate domain
  - `file.watcher.updated` -- filesystem monitoring, not session lifecycle
  """

  @handled_types [
    "server.connected",
    "server.instance.disposed",
    "session.created",
    "session.updated",
    "session.deleted",
    "session.status",
    "session.idle",
    "session.compacted",
    "session.diff",
    "session.error",
    "message.updated",
    "message.removed",
    "message.part.updated",
    "message.part.removed",
    "permission.updated",
    "permission.replied",
    "file.edited"
  ]

  @ignored_types [
    "installation.updated",
    "installation.update-available",
    "lsp.client.diagnostics",
    "lsp.updated",
    "todo.updated",
    "command.executed",
    "vcs.branch.updated",
    "tui.prompt.append",
    "tui.command.execute",
    "tui.toast.show",
    "pty.created",
    "pty.updated",
    "pty.exited",
    "pty.deleted",
    "file.watcher.updated"
  ]

  @handled_set MapSet.new(@handled_types)

  @doc "Returns the list of SDK event types handled by the Session entity."
  @spec handled_types() :: [String.t()]
  def handled_types, do: @handled_types

  @doc "Returns the list of SDK event types not relevant to the Session entity."
  @spec ignored_types() :: [String.t()]
  def ignored_types, do: @ignored_types

  @doc "Returns all 32 known SDK event types."
  @spec all_types() :: [String.t()]
  def all_types, do: @handled_types ++ @ignored_types

  @doc "Returns true if the given event type is handled by the Session entity."
  @spec handled?(String.t() | nil) :: boolean()
  def handled?(type) when is_binary(type), do: MapSet.member?(@handled_set, type)
  def handled?(_), do: false
end
