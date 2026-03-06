defmodule Agents.Sessions.Infrastructure.Clients.GithubProjectClient do
  @moduledoc """
  GitHub REST client for fetching open issues from a repository.

  Replaces the previous ProjectV2 GraphQL approach — now simply lists all
  open issues from the configured repo using the GitHub REST API.
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
          created_at: DateTime.t() | nil
        }

  @doc """
  Fetches all open issues from the configured repository.

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

  defp do_fetch_tickets(token, opts) do
    org = Keyword.fetch!(opts, :org)
    repo = Keyword.fetch!(opts, :repo)

    fetch_all_pages(token, org, repo, 1, [])
  end

  defp fetch_all_pages(token, org, repo, page, acc) do
    url = "#{@api_base}/repos/#{org}/#{repo}/issues?state=open&per_page=100&page=#{page}"

    case Req.get(url,
           headers: rest_headers(token),
           receive_timeout: 15_000,
           connect_options: [timeout: 5_000]
         ) do
      {:ok, %{status: 200, body: body}} when is_list(body) ->
        issues =
          body
          |> Enum.reject(&Map.has_key?(&1, "pull_request"))
          |> Enum.map(&parse_issue/1)

        next_acc = acc ++ issues

        if length(body) == 100 do
          fetch_all_pages(token, org, repo, page + 1, next_acc)
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
      created_at: parse_datetime(issue["created_at"]),
      labels:
        issue
        |> Map.get("labels", [])
        |> Enum.map(& &1["name"])
        |> Enum.reject(&is_nil/1)
    }
  end

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
