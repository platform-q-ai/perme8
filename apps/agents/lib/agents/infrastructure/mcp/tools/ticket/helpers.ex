defmodule Agents.Infrastructure.Mcp.Tools.Ticket.Helpers do
  @moduledoc false

  require Logger

  alias Agents.Tickets.Domain.Entities.Ticket

  # -- GitHub client helpers (deprecated, used by tools not yet migrated) ------
  # These will be removed once all tools are rewired to the domain layer.

  def github_client do
    Application.get_env(
      :agents,
      :github_ticket_client,
      Agents.Tickets.Infrastructure.Clients.GithubProjectClient
    )
  end

  def client_opts do
    config = Application.get_env(:agents, :sessions, [])

    [
      token: config[:github_token],
      org: config[:github_org] || config[:github_project_org] || "platform-q-ai",
      repo: config[:github_repo] || "perme8"
    ]
  end

  # -- Param extraction --------------------------------------------------------

  def get_param(params, key) when is_map(params) and is_atom(key) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key))
  end

  # -- Actor ID extraction -----------------------------------------------------

  @doc """
  Extracts actor_id from the MCP frame assigns.
  Falls back to "mcp-system" if no user_id is set.
  """
  def actor_id(frame) do
    frame.assigns[:user_id] || "mcp-system"
  end

  # -- Domain entity formatters ------------------------------------------------

  @doc "Formats a Ticket domain entity as detailed markdown."
  def format_ticket(%Ticket{} = ticket) do
    labels = format_list(ticket.labels || [])

    sub_issues =
      (ticket.sub_tickets || [])
      |> Enum.map_join(", ", &"##{&1.number}")
      |> blank_to_default("None")

    blockers =
      (ticket.blocked_by || [])
      |> Enum.map_join(", ", &"##{&1.number}")
      |> blank_to_default("None")

    blocking =
      (ticket.blocks || [])
      |> Enum.map_join(", ", &"##{&1.number}")
      |> blank_to_default("None")

    """
    # Ticket ##{ticket.number}

    - Title: #{ticket.title}
    - State: #{ticket.state}
    - Labels: #{labels}
    - URL: #{ticket.url || "(none)"}

    ## Body
    #{(ticket.body || "") |> blank_to_default("(empty)")}

    ## Sub-issues
    #{sub_issues}

    ## Blocked by
    #{blockers}

    ## Blocking
    #{blocking}
    """
    |> String.trim()
  end

  @doc "Formats a Ticket domain entity as a compact one-line summary."
  def format_ticket_summary(%Ticket{} = ticket) do
    labels =
      (ticket.labels || [])
      |> Enum.join(", ")
      |> blank_to_default("none")

    "Ticket ##{ticket.number}: #{ticket.title} (#{ticket.state}) [#{labels}]"
  end

  # -- Legacy GitHub issue formatters (kept for backward compat during migration)

  def format_issue(issue) do
    labels = format_list(Map.get(issue, :labels, []))
    assignees = format_list(Map.get(issue, :assignees, []))

    comments =
      issue
      |> Map.get(:comments, [])
      |> Enum.map_join("\n", fn comment ->
        "- #{Map.get(comment, :body, "")}" |> String.trim_trailing()
      end)
      |> blank_to_default("- None")

    sub_issues =
      issue
      |> Map.get(:sub_issue_numbers, [])
      |> Enum.map_join(", ", &"##{&1}")
      |> blank_to_default("None")

    """
    # Issue ##{Map.get(issue, :number)}

    - Title: #{Map.get(issue, :title, "")}
    - State: #{Map.get(issue, :state, "")}
    - Labels: #{labels}
    - Assignees: #{assignees}
    - URL: #{Map.get(issue, :url, "")}

    ## Body
    #{Map.get(issue, :body, "") |> blank_to_default("(empty)")}

    ## Comments
    #{comments}

    ## Sub-issues
    #{sub_issues}
    """
    |> String.trim()
  end

  def format_issue_summary(issue) do
    labels =
      issue
      |> Map.get(:labels, [])
      |> Enum.join(", ")
      |> blank_to_default("none")

    "Issue ##{Map.get(issue, :number)}: #{Map.get(issue, :title)} (#{Map.get(issue, :state)}) [#{labels}]"
  end

  # -- Error formatters --------------------------------------------------------

  def format_error(:not_found, context), do: "#{context} not found."
  def format_error(:ticket_not_found, context), do: "#{context} not found."
  def format_error(:no_changes, _context), do: "No updatable fields provided."
  def format_error(:parent_not_found, _context), do: "Parent ticket not found."
  def format_error(:child_not_found, _context), do: "Child ticket not found."
  def format_error(:missing_token, _context), do: "GitHub token not configured."

  def format_error(reason, _context) do
    Logger.warning("Unhandled ticket error: #{inspect(reason)}")
    "An unexpected error occurred. Check server logs for details."
  end

  defp format_list([]), do: "None"
  defp format_list(items), do: Enum.join(items, ", ")

  defp blank_to_default(nil, default), do: default

  defp blank_to_default(value, default) when is_binary(value) do
    if String.trim(value) == "", do: default, else: value
  end
end
