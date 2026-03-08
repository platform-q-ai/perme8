defmodule Agents.Sessions.Infrastructure.Clients.GithubProjectClient do
  @moduledoc """
  GitHub REST client for fetching issues from a repository.

  Replaces the previous ProjectV2 GraphQL approach — now simply lists
  issues from the configured repo using the GitHub REST API.
  Fetches both open and closed issues so the UI can filter by state.
  """

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
          state: String.t(),
          created_at: DateTime.t() | nil,
          sub_issue_numbers: [integer()]
        }

  @doc """
  Fetches all issues (open and closed) from the configured repository.

  ## Options

    * `:token` - GitHub token (required)
    * `:org` - GitHub org/owner (required)
    * `:repo` - Repository name (required)
  """
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
  Closes a GitHub issue by number using the GraphQL API.
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

  @doc """
  Fetches sub-issue numbers for a parent issue.

  Returns `{:ok, []}` on failure to avoid failing the full sync.
  """
  @spec fetch_sub_issues(String.t(), String.t(), integer(), keyword()) :: {:ok, [integer()]}
  def fetch_sub_issues(owner, repo, issue_number, opts \\ [])

  def fetch_sub_issues(owner, repo, issue_number, opts) do
    case Keyword.get(opts, :token) do
      token when is_binary(token) and token != "" ->
        api_base = Keyword.get(opts, :api_base, @api_base)
        url = "#{api_base}/repos/#{owner}/#{repo}/issues/#{issue_number}/sub_issues"

        case Req.get(url,
               headers: rest_headers(token),
               retry: false,
               receive_timeout: 15_000,
               connect_options: [timeout: 5_000]
             ) do
          {:ok, %{status: 200, body: body}} ->
            {:ok, extract_sub_issue_numbers(body)}

          {:ok, _response} ->
            {:ok, []}

          {:error, _reason} ->
            {:ok, []}
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
    api_base = Keyword.get(opts, :api_base, @api_base)
    url = "#{api_base}/repos/#{org}/#{repo}/issues?state=all&per_page=100&page=#{page}"

    case Req.get(url,
           headers: rest_headers(token),
           retry: false,
           receive_timeout: 15_000,
           connect_options: [timeout: 5_000]
         ) do
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
      labels:
        issue
        |> Map.get("labels", [])
        |> Enum.map(& &1["name"])
        |> Enum.reject(&is_nil/1)
    }
  end

  defp enrich_with_sub_issues(issues, token, owner, repo, opts) do
    issues
    |> Task.async_stream(
      fn ticket ->
        {:ok, sub_issue_numbers} =
          fetch_sub_issues(owner, repo, ticket.number,
            token: token,
            api_base: Keyword.get(opts, :api_base, @api_base)
          )

        Map.put(ticket, :sub_issue_numbers, sub_issue_numbers)
      end,
      max_concurrency: 10,
      timeout: 15_000,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, ticket} -> ticket
      {:exit, _reason} -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_sub_issue_numbers(body) when is_list(body) do
    body
    |> Enum.map(&extract_number/1)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_sub_issue_numbers(%{"sub_issues" => sub_issues}) when is_list(sub_issues) do
    extract_sub_issue_numbers(sub_issues)
  end

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
