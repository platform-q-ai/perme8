defmodule Agents.Tickets.Infrastructure.Clients.GithubProjectClient do
  @moduledoc """
  GitHub REST client for issue and ticket operations.
  """

  @behaviour Agents.Application.Behaviours.GithubTicketClientBehaviour

  @api_base "https://api.github.com"
  @graphql_url "https://api.github.com/graphql"

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
          labels: [String.t()],
          assignees: [String.t()],
          comments: [map()],
          state: String.t(),
          created_at: DateTime.t() | nil,
          sub_issue_numbers: [integer()]
        }

  @doc """
  Fetches all issues (open and closed) from the configured repository.
  """
  @spec fetch_tickets(keyword()) :: {:ok, [ticket()]} | {:error, term()}
  def fetch_tickets(opts \\ []) do
    with_token(opts, fn token -> do_fetch_tickets(token, opts) end)
  end

  @doc """
  Closes a GitHub issue by number using the GraphQL API.
  """
  @spec close_issue(integer(), keyword()) :: :ok | {:error, term()}
  def close_issue(issue_number, opts \\ []) do
    with_token(opts, fn token -> do_close_issue(token, issue_number, opts) end)
  end

  @impl true
  @spec get_issue(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_issue(issue_number, opts \\ []) do
    with_token(opts, fn token ->
      owner = Keyword.fetch!(opts, :org)
      repo = Keyword.fetch!(opts, :repo)
      issue_url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues/#{issue_number}"

      with {:ok, issue_body} <- get_ok_body(issue_url, token, opts),
           {:ok, comments_body} <- get_ok_body("#{issue_url}/comments", token, opts),
           {:ok, sub_issue_numbers} <- fetch_sub_issues(owner, repo, issue_number, opts) do
        issue =
          issue_body
          |> parse_issue()
          |> Map.put(:comments, parse_comments(comments_body))
          |> Map.put(:sub_issue_numbers, sub_issue_numbers)

        {:ok, issue}
      end
    end)
  end

  @impl true
  @spec list_issues(keyword()) :: {:ok, [map()]} | {:error, term()}
  def list_issues(opts \\ []) do
    with_token(opts, fn token ->
      owner = Keyword.fetch!(opts, :org)
      repo = Keyword.fetch!(opts, :repo)

      {url, params} = list_issues_request(owner, repo, opts)

      with {:ok, body} <- get_ok_body(url, token, Keyword.put(opts, :params, params)) do
        issues =
          body
          |> extract_issue_list()
          |> Enum.reject(&Map.has_key?(&1, "pull_request"))
          |> Enum.map(&parse_issue/1)

        {:ok, issues}
      end
    end)
  end

  @impl true
  @spec create_issue(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def create_issue(attrs, opts \\ []) do
    with_token(opts, fn token ->
      owner = Keyword.fetch!(opts, :org)
      repo = Keyword.fetch!(opts, :repo)
      url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues"

      payload =
        attrs
        |> normalize_attrs_map()
        |> Map.take(["title", "body", "labels", "assignees"])
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      with {:ok, body} <- post_ok_body(url, token, payload, opts, [201]) do
        {:ok, parse_issue(body)}
      end
    end)
  end

  @impl true
  @spec update_issue(integer(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def update_issue(issue_number, attrs, opts \\ []) do
    with_token(opts, fn token ->
      owner = Keyword.fetch!(opts, :org)
      repo = Keyword.fetch!(opts, :repo)
      url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues/#{issue_number}"

      payload =
        attrs
        |> normalize_attrs_map()
        |> Map.take(["title", "body", "labels", "assignees", "state"])
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()

      with {:ok, body} <- patch_ok_body(url, token, payload, opts) do
        {:ok, parse_issue(body)}
      end
    end)
  end

  @impl true
  @spec close_issue_with_comment(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def close_issue_with_comment(issue_number, opts \\ []) do
    with_token(opts, fn token ->
      owner = Keyword.fetch!(opts, :org)
      repo = Keyword.fetch!(opts, :repo)
      issue_url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues/#{issue_number}"

      with :ok <- maybe_add_closing_comment(issue_url, issue_number, token, opts),
           {:ok, body} <- patch_ok_body(issue_url, token, %{"state" => "closed"}, opts) do
        {:ok, parse_issue(body)}
      end
    end)
  end

  @impl true
  @spec add_comment(integer(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def add_comment(issue_number, comment, opts \\ []) do
    with_token(opts, fn token ->
      owner = Keyword.fetch!(opts, :org)
      repo = Keyword.fetch!(opts, :repo)
      url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues/#{issue_number}/comments"

      with {:ok, body} <- post_ok_body(url, token, %{"body" => comment}, opts, [201]) do
        {:ok, parse_comment(body)}
      end
    end)
  end

  @impl true
  @spec add_sub_issue(integer(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def add_sub_issue(parent_number, child_number, opts \\ []) do
    with_token(opts, fn token ->
      owner = Keyword.fetch!(opts, :org)
      repo = Keyword.fetch!(opts, :repo)
      url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues/#{parent_number}/sub_issues"

      with {:ok, child_node_id} <- get_issue_node_id(child_number, owner, repo, token, opts),
           {:ok, _body} <- post_ok_body(url, token, %{"sub_issue_id" => child_node_id}, opts) do
        {:ok, %{parent_number: parent_number, child_number: child_number}}
      else
        {:error, :not_found} ->
          {:error, sub_issue_api_error(404, %{"message" => "Not Found"})}

        {:error, {:unexpected_status, status, body}} when status in [404, 422] ->
          {:error, sub_issue_api_error(status, body)}

        error ->
          error
      end
    end)
  end

  @impl true
  @spec remove_sub_issue(integer(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def remove_sub_issue(parent_number, child_number, opts \\ []) do
    with_token(opts, fn token ->
      owner = Keyword.fetch!(opts, :org)
      repo = Keyword.fetch!(opts, :repo)
      url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues/#{parent_number}/sub_issues"

      with {:ok, child_node_id} <- get_issue_node_id(child_number, owner, repo, token, opts),
           {:ok, _body} <-
             delete_ok_body(url, token, %{"sub_issue_id" => child_node_id}, opts, [200, 204]) do
        {:ok, %{parent_number: parent_number, child_number: child_number}}
      else
        {:error, :not_found} ->
          {:error, sub_issue_api_error(404, %{"message" => "Not Found"})}

        {:error, {:unexpected_status, status, body}} when status in [404, 422] ->
          {:error, sub_issue_api_error(status, body)}

        error ->
          error
      end
    end)
  end

  @doc """
  Fetches sub-issue numbers for a parent issue.

  Returns `{:ok, []}` on failure to avoid failing the full sync.
  """
  @spec fetch_sub_issues(String.t(), String.t(), integer(), keyword()) :: {:ok, [integer()]}
  def fetch_sub_issues(owner, repo, issue_number, opts \\ []) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) and token != "" ->
        url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues/#{issue_number}/sub_issues"

        case Req.get(url, request_opts(token, opts)) do
          {:ok, %{status: 200, body: body}} -> {:ok, extract_sub_issue_numbers(body)}
          {:ok, _response} -> {:ok, []}
          {:error, _reason} -> {:ok, []}
        end

      _ ->
        {:ok, []}
    end
  end

  defp do_fetch_tickets(token, opts) do
    org = Keyword.fetch!(opts, :org)
    repo = Keyword.fetch!(opts, :repo)

    fetch_all_pages(token, org, repo, 1, [], opts)
  end

  defp fetch_all_pages(token, org, repo, page, acc, opts) do
    url = "#{api_base(opts)}/repos/#{org}/#{repo}/issues?state=all&per_page=100&page=#{page}"

    case Req.get(url, request_opts(token, opts)) do
      {:ok, %{status: 200, body: body}} when is_list(body) ->
        issues_without_sub_issues =
          body
          |> Enum.reject(&Map.has_key?(&1, "pull_request"))
          |> Enum.map(&parse_issue/1)

        issues = enrich_with_sub_issues(issues_without_sub_issues, token, org, repo, opts)
        next_acc = acc ++ issues

        if length(body) == 100 do
          fetch_all_pages(token, org, repo, page + 1, next_acc, opts)
        else
          {:ok, next_acc}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, {:unexpected_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_issue(issue) do
    %{
      number: issue["number"],
      title: issue["title"],
      body: issue["body"],
      url: issue["html_url"],
      state: issue["state"] || "open",
      created_at: parse_datetime(issue["created_at"]),
      sub_issue_numbers: [],
      comments: [],
      assignees:
        issue
        |> Map.get("assignees", [])
        |> Enum.map(& &1["login"])
        |> Enum.reject(&is_nil/1),
      labels:
        issue
        |> Map.get("labels", [])
        |> Enum.map(& &1["name"])
        |> Enum.reject(&is_nil/1)
    }
  end

  defp parse_comment(comment) do
    %{
      id: comment["id"],
      body: comment["body"],
      url: comment["html_url"],
      created_at: parse_datetime(comment["created_at"])
    }
  end

  defp parse_comments(comments) when is_list(comments), do: Enum.map(comments, &parse_comment/1)
  defp parse_comments(_), do: []

  defp enrich_with_sub_issues(issues, token, owner, repo, opts) do
    enrichment_timeout = Keyword.get(opts, :enrichment_timeout, 15_000)

    issues
    |> Task.async_stream(
      fn ticket ->
        {:ok, sub_issue_numbers} =
          fetch_sub_issues(owner, repo, ticket.number,
            token: token,
            api_base: api_base(opts),
            req_options: Keyword.get(opts, :req_options, [])
          )

        Map.put(ticket, :sub_issue_numbers, sub_issue_numbers)
      end,
      max_concurrency: 10,
      timeout: enrichment_timeout,
      on_timeout: :kill_task
    )
    |> Enum.zip(issues)
    |> Enum.map(fn
      {{:ok, enriched_ticket}, _original} -> enriched_ticket
      {{:exit, _reason}, original} -> original
    end)
  end

  defp extract_sub_issue_numbers(body) when is_list(body) do
    body
    |> Enum.map(&extract_number/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_sub_issue_numbers(%{"sub_issues" => sub_issues}) when is_list(sub_issues),
    do: extract_sub_issue_numbers(sub_issues)

  defp extract_sub_issue_numbers(_), do: []

  defp extract_number(%{"number" => number}) when is_integer(number), do: number
  defp extract_number(%{number: number}) when is_integer(number), do: number
  defp extract_number(_), do: nil

  defp parse_datetime(nil), do: nil

  defp parse_datetime(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
      _ -> nil
    end
  end

  defp do_close_issue(token, issue_number, opts) do
    org = Keyword.get(opts, :org, "platform-q-ai")
    repo = Keyword.get(opts, :repo, "perme8")

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

  defp graphql_post(token, body) do
    case Req.post(@graphql_url, json: body, headers: base_headers(token)) do
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

  defp with_token(opts, fun) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) and token != "" -> fun.(token)
      _ -> {:error, :missing_token}
    end
  end

  defp request_opts(token, opts) do
    Keyword.merge(
      [
        headers: rest_headers(token),
        retry: false,
        receive_timeout: 15_000,
        connect_options: [timeout: 5_000],
        params: Keyword.get(opts, :params, [])
      ],
      Keyword.get(opts, :req_options, [])
    )
  end

  defp api_base(opts), do: Keyword.get(opts, :api_base, @api_base)

  defp get_ok_body(url, token, opts, statuses \\ [200]) do
    case Req.get(url, request_opts(token, opts)) do
      {:ok, %{status: status, body: body}} ->
        if(status in statuses, do: {:ok, body}, else: error_for_status(status, body))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp post_ok_body(url, token, payload, opts, statuses \\ [200]) do
    request = Keyword.put(request_opts(token, opts), :json, payload)

    case Req.post(url, request) do
      {:ok, %{status: status, body: body}} ->
        if(status in statuses, do: {:ok, body}, else: error_for_status(status, body))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp patch_ok_body(url, token, payload, opts, statuses \\ [200]) do
    request = Keyword.put(request_opts(token, opts), :json, payload)

    case Req.patch(url, request) do
      {:ok, %{status: status, body: body}} ->
        if(status in statuses, do: {:ok, body}, else: error_for_status(status, body))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp error_for_status(404, _body), do: {:error, :not_found}
  defp error_for_status(status, body), do: {:error, {:unexpected_status, status, body}}

  defp delete_ok_body(url, token, payload, opts, statuses) do
    request =
      request_opts(token, opts)
      |> Keyword.put(:method, :delete)
      |> Keyword.put(:url, url)
      |> Keyword.put(:json, payload)

    case Req.request(request) do
      {:ok, %{status: status, body: body}} ->
        if(status in statuses, do: {:ok, body}, else: error_for_status(status, body))

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp maybe_add_closing_comment(issue_url, issue_number, token, opts) do
    case Keyword.get(opts, :comment) do
      comment when is_binary(comment) and comment != "" ->
        case post_ok_body("#{issue_url}/comments", token, %{"body" => comment}, opts, [201]) do
          {:ok, _comment} -> :ok
          {:error, :not_found} -> {:error, :not_found}
          {:error, reason} -> {:error, {:close_issue_comment_failed, issue_number, reason}}
        end

      _ ->
        :ok
    end
  end

  defp get_issue_node_id(issue_number, owner, repo, token, opts) do
    issue_url = "#{api_base(opts)}/repos/#{owner}/#{repo}/issues/#{issue_number}"

    with {:ok, issue} <- get_ok_body(issue_url, token, opts) do
      case issue["node_id"] do
        node_id when is_binary(node_id) and node_id != "" -> {:ok, node_id}
        _ -> {:error, :missing_node_id}
      end
    end
  end

  defp list_issues_request(owner, repo, opts) do
    per_page = Keyword.get(opts, :per_page, 100)

    case Keyword.get(opts, :query) do
      query when is_binary(query) and query != "" ->
        terms =
          [
            query,
            "repo:#{owner}/#{repo}",
            query_filter("state", opts),
            query_filter("label", opts),
            query_filter("assignee", opts)
          ]
          |> Enum.reject(&is_nil/1)

        {"#{api_base(opts)}/search/issues", [q: Enum.join(terms, " "), per_page: per_page]}

      _ ->
        params =
          [
            state: Keyword.get(opts, :state, "open"),
            labels: labels_param(Keyword.get(opts, :labels)),
            assignee: Keyword.get(opts, :assignee),
            per_page: per_page
          ]
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)

        {"#{api_base(opts)}/repos/#{owner}/#{repo}/issues", params}
    end
  end

  defp extract_issue_list(%{"items" => items}) when is_list(items), do: items
  defp extract_issue_list(items) when is_list(items), do: items
  defp extract_issue_list(_), do: []

  defp labels_param(labels) when is_list(labels), do: Enum.join(labels, ",")
  defp labels_param(_), do: nil

  defp query_filter("state", opts) do
    case Keyword.get(opts, :state) do
      value when is_binary(value) and value != "" -> "state:#{value}"
      _ -> nil
    end
  end

  defp query_filter("label", opts) do
    case Keyword.get(opts, :labels) do
      labels when is_list(labels) and labels != [] ->
        labels
        |> Enum.reject(&(&1 in [nil, ""]))
        |> Enum.map_join(" ", &"label:#{&1}")

      _ ->
        nil
    end
  end

  defp query_filter("assignee", opts) do
    case Keyword.get(opts, :assignee) do
      value when is_binary(value) and value != "" -> "assignee:#{value}"
      _ -> nil
    end
  end

  defp normalize_attrs_map(attrs) when is_map(attrs) do
    attrs
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
    |> Map.new()
  end

  defp sub_issue_api_error(status, body) do
    message =
      case body do
        %{"message" => api_message} when is_binary(api_message) -> api_message
        _ -> "GitHub API returned status #{status}"
      end

    "Unable to modify sub-issue relationship: #{message}"
  end

  defp rest_headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"accept", "application/vnd.github+json"},
      {"x-github-api-version", "2022-11-28"},
      {"user-agent", "perme8-agents"}
    ]
  end

  defp base_headers(token) do
    [
      {"authorization", "Bearer #{token}"},
      {"content-type", "application/json"},
      {"user-agent", "perme8-agents"}
    ]
  end
end
