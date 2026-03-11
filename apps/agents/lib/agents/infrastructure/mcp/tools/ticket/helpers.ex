defmodule Agents.Infrastructure.Mcp.Tools.Ticket.Helpers do
  @moduledoc false

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

  def get_param(params, key) when is_map(params) and is_atom(key) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key))
  end

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

  def format_error(:not_found, context), do: "#{context} not found."
  def format_error(:missing_token, _context), do: "GitHub token not configured."
  def format_error(reason, _context), do: "An unexpected error occurred: #{inspect(reason)}"

  defp format_list([]), do: "None"
  defp format_list(items), do: Enum.join(items, ", ")

  defp blank_to_default(value, default) when is_binary(value) do
    if String.trim(value) == "", do: default, else: value
  end
end
