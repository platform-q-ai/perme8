defmodule Agents.Sessions.Infrastructure.Clients.GithubProjectClient do
  @moduledoc """
  GitHub GraphQL client for ProjectV2-backed session tickets.

  Fetches issue items from a single project and filters by configured
  board statuses (for example: Backlog and Ready).
  """

  @graphql_url "https://api.github.com/graphql"
  @project_status_field_id "PVTSSF_lADOAY59zs4BPTB1zg9vwck"
  @project_priority_field_id "PVTSSF_lADOAY59zs4BPTB1zg9vwdw"

  @status_option_ids %{
    "Backlog" => "f75ad846",
    "Ready" => "e18bf179",
    "In progress" => "47fc9ee4",
    "In review" => "aba860b9",
    "Done" => "98236657"
  }

  @priority_option_ids %{
    "Need" => "79628723",
    "Want" => "0a877460",
    "Nice to have" => "da944a9c"
  }

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
                body
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
            sizeField: fieldValueByName(name: "Size") {
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
          body: String.t() | nil,
          url: String.t() | nil,
          status: String.t() | nil,
          priority: String.t() | nil,
          size: String.t() | nil,
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

  @doc """
  Pushes a locally edited ticket's project fields back to GitHub ProjectV2.
  """
  @spec push_ticket_update(map(), keyword()) :: :ok | {:error, term()}
  def push_ticket_update(ticket, opts \\ []) do
    token = Keyword.get(opts, :token)

    if is_binary(token) and token != "" do
      do_push_ticket_update(token, ticket, opts)
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
      body: issue["body"],
      url: issue["url"],
      status: get_in(node, ["statusField", "name"]),
      priority: get_in(node, ["priorityField", "name"]),
      size: get_in(node, ["sizeField", "name"]),
      labels:
        issue
        |> get_in(["labels", "nodes"])
        |> List.wrap()
        |> Enum.map(& &1["name"])
        |> Enum.reject(&is_nil/1)
    }
  end

  defp parse_ticket_node(_), do: nil

  defp do_push_ticket_update(token, ticket, opts) do
    org = Keyword.fetch!(opts, :org)
    project_number = Keyword.fetch!(opts, :project_number)

    with {:ok, item_id} <- project_item_id(token, org, project_number, ticket.number),
         :ok <-
           maybe_update_single_select(
             token,
             item_id,
             @project_status_field_id,
             ticket.status,
             @status_option_ids
           ) do
      maybe_update_single_select(
        token,
        item_id,
        @project_priority_field_id,
        ticket.priority,
        @priority_option_ids
      )
    end
  end

  defp project_item_id(token, org, project_number, issue_number) do
    query = """
    query($org: String!, $projectNumber: Int!, $after: String) {
      organization(login: $org) {
        projectV2(number: $projectNumber) {
          items(first: 100, after: $after) {
            nodes {
              id
              content {
                ... on Issue {
                  number
                }
              }
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      }
    }
    """

    find_project_item_id(token, query, %{org: org, projectNumber: project_number}, issue_number)
  end

  defp find_project_item_id(token, query, variables, issue_number) do
    case Req.post(@graphql_url,
           json: %{query: query, variables: variables},
           headers: base_headers(token)
         ) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        items = get_in(data, ["organization", "projectV2", "items"])

        item_id =
          items
          |> get_in(["nodes"])
          |> List.wrap()
          |> Enum.find_value(fn
            %{"content" => %{"number" => ^issue_number}, "id" => item_id} -> item_id
            _ -> nil
          end)

        cond do
          is_binary(item_id) ->
            {:ok, item_id}

          get_in(items, ["pageInfo", "hasNextPage"]) == true ->
            find_project_item_id(
              token,
              query,
              Map.put(variables, :after, get_in(items, ["pageInfo", "endCursor"])),
              issue_number
            )

          true ->
            {:error, :project_item_not_found}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_update_single_select(_token, _item_id, _field_id, value, _option_ids)
       when value in [nil, ""] do
    :ok
  end

  defp maybe_update_single_select(token, item_id, field_id, value, option_ids) do
    case Map.get(option_ids, value) do
      nil ->
        {:error, {:unsupported_option, field_id, value}}

      option_id ->
        mutation = """
        mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projectId,
            itemId: $itemId,
            fieldId: $fieldId,
            value: { singleSelectOptionId: $optionId }
          }) {
            projectV2Item { id }
          }
        }
        """

        variables = %{
          projectId: "PVT_kwDOAY59zs4BPTB1",
          itemId: item_id,
          fieldId: field_id,
          optionId: option_id
        }

        case Req.post(@graphql_url,
               json: %{query: mutation, variables: variables},
               headers: base_headers(token)
             ) do
          {:ok, %{status: 200}} -> :ok
          {:ok, %{status: status, body: body}} -> {:error, {:unexpected_status, status, body}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp base_headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"content-type", "application/json"},
      {"user-agent", "perme8-agents"}
    ]
  end
end
