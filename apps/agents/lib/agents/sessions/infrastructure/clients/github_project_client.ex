defmodule Agents.Sessions.Infrastructure.Clients.GithubProjectClient do
  @moduledoc """
  GitHub GraphQL client for ProjectV2-backed session tickets.

  Fetches issue items from a single project and filters by configured
  board statuses (for example: Backlog and Ready).
  """

  @graphql_url "https://api.github.com/graphql"

  @query """
  query($org: String!, $projectNumber: Int!) {
    organization(login: $org) {
      projectV2(number: $projectNumber) {
        items(first: 100) {
          nodes {
            content {
              ... on Issue {
                number
                title
                url
                labels(first: 10) {
                  nodes {
                    name
                  }
                }
              }
            }
            statusField: fieldValueByName(name: "Status") {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
              }
            }
            priorityField: fieldValueByName(name: "Priority") {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
              }
            }
          }
        }
      }
    }
  }
  """

  @type ticket :: %{
          number: integer(),
          title: String.t(),
          url: String.t() | nil,
          status: String.t() | nil,
          priority: String.t() | nil,
          labels: [String.t()]
        }

  @spec fetch_tickets(keyword()) :: {:ok, [ticket()]} | {:error, term()}
  def fetch_tickets(opts \\ []) do
    token = Keyword.get(opts, :token)

    if is_binary(token) and token != "" do
      do_fetch_tickets(token, opts)
    else
      {:error, :missing_token}
    end
  end

  defp do_fetch_tickets(token, opts) do
    org = Keyword.fetch!(opts, :org)
    project_number = Keyword.fetch!(opts, :project_number)
    statuses = MapSet.new(Keyword.get(opts, :statuses, ["Backlog", "Ready"]))

    body = %{
      query: @query,
      variables: %{
        org: org,
        projectNumber: project_number
      }
    }

    case Req.post(@graphql_url,
           json: body,
           headers: [
             {"authorization", "Bearer #{token}"},
             {"content-type", "application/json"},
             {"user-agent", "perme8-agents"}
           ]
         ) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        tickets =
          data
          |> get_in(["organization", "projectV2", "items", "nodes"])
          |> List.wrap()
          |> Enum.map(&parse_ticket_node/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(fn ticket -> MapSet.member?(statuses, ticket.status) end)

        {:ok, tickets}

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_ticket_node(%{"content" => %{"number" => number, "title" => title} = issue} = node)
       when is_integer(number) and is_binary(title) do
    %{
      number: number,
      title: title,
      url: issue["url"],
      status: get_in(node, ["statusField", "name"]),
      priority: get_in(node, ["priorityField", "name"]),
      labels:
        issue
        |> get_in(["labels", "nodes"])
        |> List.wrap()
        |> Enum.map(& &1["name"])
        |> Enum.reject(&is_nil/1)
    }
  end

  defp parse_ticket_node(_), do: nil
end
