defmodule Agents.Tickets.Infrastructure.Clients.StubGithubTicketClient do
  @moduledoc """
  In-memory stub implementing `GithubTicketClientBehaviour` for use in exo-bdd
  integration tests where no real GitHub token is available.

  Returns deterministic canned responses. Issue numbers 1 and 2 are "known";
  any other number returns `{:error, :not_found}`. Create always succeeds and
  returns a synthetic issue number.
  """

  @behaviour Agents.Application.Behaviours.GithubTicketClientBehaviour

  @known_issues %{
    1 => %{
      number: 1,
      title: "Stub Issue One",
      body: "Body of stub issue one.",
      state: "open",
      labels: ["enhancement", "agents"],
      assignees: ["stub-user"],
      url: "https://github.com/platform-q-ai/perme8/issues/1",
      comments: [%{body: "A stub comment"}],
      sub_issue_numbers: [2],
      created_at: "2025-01-01T00:00:00Z"
    },
    2 => %{
      number: 2,
      title: "Stub Issue Two",
      body: "Body of stub issue two.",
      state: "open",
      labels: ["bug"],
      assignees: [],
      url: "https://github.com/platform-q-ai/perme8/issues/2",
      comments: [],
      sub_issue_numbers: [],
      created_at: "2025-01-02T00:00:00Z"
    }
  }

  @impl true
  def get_issue(number, _opts) do
    case Map.fetch(@known_issues, number) do
      {:ok, issue} -> {:ok, issue}
      :error -> {:error, :not_found}
    end
  end

  @impl true
  def list_issues(opts) do
    issues = Map.values(@known_issues)

    filtered =
      issues
      |> maybe_filter_state(Keyword.get(opts, :state))
      |> maybe_filter_labels(Keyword.get(opts, :labels))

    {:ok, filtered}
  end

  @impl true
  def create_issue(attrs, _opts) do
    issue = %{
      number: 9999,
      title: Map.get(attrs, :title, "Untitled"),
      body: Map.get(attrs, :body, ""),
      state: "open",
      labels: Map.get(attrs, :labels, []) || [],
      assignees: Map.get(attrs, :assignees, []) || [],
      url: "https://github.com/platform-q-ai/perme8/issues/9999",
      comments: [],
      sub_issue_numbers: [],
      created_at: "2025-06-01T00:00:00Z"
    }

    {:ok, issue}
  end

  @impl true
  def update_issue(number, attrs, _opts) do
    case Map.fetch(@known_issues, number) do
      {:ok, issue} ->
        updated =
          issue
          |> maybe_put(:title, Map.get(attrs, :title))
          |> maybe_put(:body, Map.get(attrs, :body))
          |> maybe_put(:labels, Map.get(attrs, :labels))
          |> maybe_put(:assignees, Map.get(attrs, :assignees))
          |> maybe_put(:state, Map.get(attrs, :state))

        {:ok, updated}

      :error ->
        {:error, :not_found}
    end
  end

  @impl true
  def close_issue_with_comment(number, _opts) do
    case Map.fetch(@known_issues, number) do
      {:ok, issue} -> {:ok, %{issue | state: "closed"}}
      :error -> {:error, :not_found}
    end
  end

  @impl true
  def add_comment(number, body, _opts) do
    case Map.fetch(@known_issues, number) do
      {:ok, _issue} ->
        {:ok,
         %{
           id: 42,
           body: body,
           url: "https://github.com/platform-q-ai/perme8/issues/#{number}#issuecomment-42",
           created_at: "2025-06-01T00:00:00Z"
         }}

      :error ->
        {:error, :not_found}
    end
  end

  @impl true
  def add_sub_issue(parent_number, child_number, _opts) do
    with {:parent, {:ok, _}} <- {:parent, Map.fetch(@known_issues, parent_number)},
         {:child, {:ok, _}} <- {:child, Map.fetch(@known_issues, child_number)} do
      {:ok, %{parent_number: parent_number, child_number: child_number}}
    else
      {:parent, :error} -> {:error, :not_found}
      {:child, :error} -> {:error, :not_found}
    end
  end

  @impl true
  def remove_sub_issue(parent_number, child_number, _opts) do
    with {:parent, {:ok, _}} <- {:parent, Map.fetch(@known_issues, parent_number)},
         {:child, {:ok, _}} <- {:child, Map.fetch(@known_issues, child_number)} do
      {:ok, %{parent_number: parent_number, child_number: child_number}}
    else
      {:parent, :error} -> {:error, :not_found}
      {:child, :error} -> {:error, :not_found}
    end
  end

  # --- Private helpers ---

  defp maybe_filter_state(issues, nil), do: issues
  defp maybe_filter_state(issues, "all"), do: issues

  defp maybe_filter_state(issues, state) do
    Enum.filter(issues, &(&1.state == state))
  end

  defp maybe_filter_labels(issues, nil), do: issues
  defp maybe_filter_labels(issues, []), do: issues

  defp maybe_filter_labels(issues, labels) do
    Enum.filter(issues, fn issue ->
      Enum.any?(labels, &(&1 in issue.labels))
    end)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
