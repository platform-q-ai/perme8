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
  query($org: String!, $projectNumber: Int!, $after: String) {
    organization(login: $org) {
      projectV2(number: $projectNumber) {
        id
        fields(first: 50) {
          nodes {
            ... on ProjectV2SingleSelectField {
              id
              name
              options {
                id
                name
              }
            }
          }
        }
        items(first: 100, after: $after) {
          nodes {
            id
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
                optionId
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
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    }
  }
  """

  @update_position_mutation """
  mutation($projectId: ID!, $itemId: ID!, $afterId: ID) {
    updateProjectV2ItemPosition(input: {projectId: $projectId, itemId: $itemId, afterId: $afterId}) {
      items(first: 1) {
        nodes {
          id
        }
      }
    }
  }
  """

  @update_status_mutation """
  mutation($projectId: ID!, $itemId: ID!, $fieldId: ID!, $optionId: String!) {
    updateProjectV2ItemFieldValue(
      input: {
        projectId: $projectId,
        itemId: $itemId,
        fieldId: $fieldId,
        value: {singleSelectOptionId: $optionId}
      }
    ) {
      projectV2Item {
        id
      }
    }
  }
  """

  @close_issue_mutation """
  mutation($issueId: ID!) {
    closeIssue(input: {issueId: $issueId}) {
      issue {
        id
        state
      }
    }
  }
  """

  @issue_id_query """
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        id
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
          labels: [String.t()],
          item_id: String.t() | nil,
          status_option_id: String.t() | nil
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

  @spec update_ticket_order_and_status(keyword()) :: :ok | {:error, term()}
  def update_ticket_order_and_status(opts) do
    token = Keyword.get(opts, :token)

    if is_binary(token) and token != "" do
      do_update_ticket_order_and_status(token, opts)
    else
      {:error, :missing_token}
    end
  end

  @doc """
  Closes a GitHub issue by number.

  Sets the board status to "Done" and closes the actual issue via the
  `closeIssue` GraphQL mutation.
  """
  @spec close_issue(integer(), keyword()) :: :ok | {:error, term()}
  def close_issue(issue_number, opts \\ []) do
    token = Keyword.get(opts, :token)

    if is_binary(token) and token != "" do
      do_close_issue(token, issue_number, opts)
    else
      {:error, :missing_token}
    end
  end

  defp do_close_issue(token, issue_number, opts) do
    org = Keyword.get(opts, :org, "platform-q-ai")
    repo = Keyword.get(opts, :repo, "perme8")
    project_number = Keyword.get(opts, :project_number)

    # 1. Set board status to "Done" if we have project context
    if project_number do
      with {:ok, item_id} <- project_item_id(token, org, project_number, issue_number) do
        maybe_update_single_select(
          token,
          item_id,
          @project_status_field_id,
          "Done",
          @status_option_ids
        )
      end
    end

    # 2. Close the actual GitHub issue
    with {:ok, issue_id} <- fetch_issue_id(token, org, repo, issue_number) do
      graphql_post(token, %{
        query: @close_issue_mutation,
        variables: %{issueId: issue_id}
      })
    end
  end

  defp fetch_issue_id(token, owner, repo, issue_number) do
    case Req.post(@graphql_url,
           json: %{
             query: @issue_id_query,
             variables: %{owner: owner, name: repo, number: issue_number}
           },
           headers: base_headers(token)
         ) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        case get_in(data, ["repository", "issue", "id"]) do
          id when is_binary(id) -> {:ok, id}
          _ -> {:error, :issue_not_found}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_fetch_tickets(token, opts) do
    org = Keyword.fetch!(opts, :org)
    project_number = Keyword.fetch!(opts, :project_number)
    statuses = MapSet.new(Keyword.get(opts, :statuses, ["Backlog", "Ready"]))

    fetch_pages(token, org, project_number, statuses, nil, [])
  end

  defp do_update_ticket_order_and_status(token, opts) do
    project_id = Keyword.fetch!(opts, :project_id)
    item_id = Keyword.fetch!(opts, :item_id)
    after_item_id = Keyword.get(opts, :after_item_id)
    status_field_id = Keyword.get(opts, :status_field_id)
    target_status_option_id = Keyword.get(opts, :target_status_option_id)

    with :ok <-
           maybe_update_ticket_status(
             token,
             project_id,
             item_id,
             status_field_id,
             target_status_option_id
           ) do
      update_ticket_position(token, project_id, item_id, after_item_id)
    end
  end

  defp maybe_update_ticket_status(_token, _project_id, _item_id, _field_id, nil), do: :ok
  defp maybe_update_ticket_status(_token, _project_id, _item_id, nil, _option_id), do: :ok

  defp maybe_update_ticket_status(token, project_id, item_id, field_id, option_id) do
    body = %{
      query: @update_status_mutation,
      variables: %{
        projectId: project_id,
        itemId: item_id,
        fieldId: field_id,
        optionId: option_id
      }
    }

    graphql_post(token, body)
  end

  defp update_ticket_position(token, project_id, item_id, after_item_id) do
    body = %{
      query: @update_position_mutation,
      variables: %{
        projectId: project_id,
        itemId: item_id,
        afterId: after_item_id
      }
    }

    graphql_post(token, body)
  end

  defp fetch_pages(token, org, project_number, statuses, after_cursor, acc) do
    body = %{
      query: @query,
      variables: %{
        org: org,
        projectNumber: project_number,
        after: after_cursor
      }
    }

    case Req.post(@graphql_url,
           json: body,
           headers: base_headers(token)
         ) do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        project = get_in(data, ["organization", "projectV2"]) || %{}
        items = Map.get(project, "items", %{})
        metadata = extract_project_metadata(project)

        page_tickets =
          items
          |> Map.get("nodes", [])
          |> List.wrap()
          |> Enum.map(&parse_ticket_node(&1, metadata))
          |> Enum.reject(&is_nil/1)
          |> Enum.filter(fn ticket -> MapSet.member?(statuses, ticket.status) end)

        page_info = Map.get(items, "pageInfo", %{})
        has_next_page = Map.get(page_info, "hasNextPage", false)
        next_cursor = Map.get(page_info, "endCursor")
        next_acc = acc ++ page_tickets

        if has_next_page and is_binary(next_cursor) and next_cursor != "" do
          fetch_pages(token, org, project_number, statuses, next_cursor, next_acc)
        else
          {:ok, next_acc}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_ticket_node(
         %{"content" => %{"number" => number, "title" => title} = issue} = node,
         metadata
       )
       when is_integer(number) and is_binary(title) do
    %{
      number: number,
      title: title,
      body: issue["body"],
      url: issue["url"],
      status: get_in(node, ["statusField", "name"]),
      status_option_id: get_in(node, ["statusField", "optionId"]),
      priority: get_in(node, ["priorityField", "name"]),
      size: get_in(node, ["sizeField", "name"]),
      item_id: node["id"],
      project_id: metadata.project_id,
      status_field_id: metadata.status_field_id,
      status_option_ids: metadata.status_option_ids,
      labels:
        issue
        |> get_in(["labels", "nodes"])
        |> List.wrap()
        |> Enum.map(& &1["name"])
        |> Enum.reject(&is_nil/1)
    }
  end

  defp parse_ticket_node(_, _metadata), do: nil

  defp extract_project_metadata(project) do
    status_field =
      project
      |> get_in(["fields", "nodes"])
      |> List.wrap()
      |> Enum.find(fn field -> field["name"] == "Status" end)

    status_option_ids =
      status_field
      |> Map.get("options", [])
      |> List.wrap()
      |> Enum.reduce(%{}, fn option, acc ->
        case {option["name"], option["id"]} do
          {name, id} when is_binary(name) and is_binary(id) -> Map.put(acc, name, id)
          _ -> acc
        end
      end)

    %{
      project_id: project["id"],
      status_field_id: status_field && status_field["id"],
      status_option_ids: status_option_ids
    }
  end

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
        graphql_post(token, %{
          query: @update_status_mutation,
          variables: %{
            projectId: "PVT_kwDOAY59zs4BPTB1",
            itemId: item_id,
            fieldId: field_id,
            optionId: option_id
          }
        })
    end
  end

  defp graphql_post(token, body) do
    case Req.post(@graphql_url,
           json: body,
           headers: base_headers(token)
         ) do
      {:ok, %{status: 200, body: %{"errors" => errors}}} when is_list(errors) and errors != [] ->
        {:error, {:graphql_errors, errors}}

      {:ok, %{status: 200}} ->
        :ok

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
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
