defmodule AgentsWeb.DashboardLive.PRHandlers do
  @moduledoc "Loads PR tab data and handles PR tab interactions."

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]

  import AgentsWeb.DashboardLive.SessionDataHelpers,
    only: [find_ticket_by_number: 2, session_tabs: 1, linked_pull_request_for_ticket: 1]

  alias Agents.Pipeline

  def load_pr_tab(socket, active_ticket_number, active_tab) do
    selected_ticket = find_ticket_by_number(socket.assigns.tickets, active_ticket_number)

    {selected_pr, has_pr_tab, pr_lookup_error} =
      case linked_pull_request_for_ticket(selected_ticket) do
        {:ok, pr} -> {pr, true, nil}
        {:error, :not_found} -> {nil, false, nil}
        {:error, reason} -> {nil, false, reason}
      end

    detail_tabs =
      if selected_ticket, do: session_tabs(has_pr_tab), else: [%{id: "chat", label: "Chat"}]

    socket =
      socket
      |> assign(:selected_ticket, selected_ticket)
      |> assign(:selected_pull_request, selected_pr)
      |> assign(:detail_tabs, detail_tabs)
      |> assign(:pr_lookup_error, pr_lookup_error)

    if active_tab == "pr" and selected_pr do
      load_pr_content(socket, selected_pr)
    else
      socket
      |> assign(:pr_diff_payload, [])
      |> assign(:pr_review_threads, grouped_review_threads(selected_pr))
      |> assign(:pr_loading, false)
      |> assign(:pr_error, nil)
      |> assign(:pr_review_decision, "comment")
    end
  end

  def add_inline_comment(%{"comment" => %{"body" => body}}, socket) do
    with {:ok, pr} <- require_selected_pr(socket),
         true <- String.trim(body) != "",
         {:ok, _updated} <-
           Pipeline.comment_on_pull_request(pr.number, %{
             actor_id: actor_id(socket),
             body: String.trim(body),
             path: "unknown",
             line: 1
           }) do
      {:noreply,
       socket
       |> assign(:show_inline_comment_form, false)
       |> assign(:inline_comment_body, "")
       |> reload_pr_after_mutation()}
    else
      false -> {:noreply, put_flash(socket, :error, "Comment cannot be empty")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def add_inline_comment(_params, socket), do: {:noreply, socket}

  def reply_to_thread(%{"comment_id" => comment_id, "reply" => %{"body" => body}}, socket) do
    with {:ok, pr} <- require_selected_pr(socket),
         true <- String.trim(body) != "",
         {:ok, _updated} <-
           Pipeline.reply_to_pull_request_comment(pr.number, comment_id, %{
             actor_id: actor_id(socket),
             body: String.trim(body)
           }) do
      {:noreply, reload_pr_after_mutation(socket)}
    else
      false -> {:noreply, put_flash(socket, :error, "Reply cannot be empty")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def reply_to_thread(_params, socket), do: {:noreply, socket}

  def resolve_thread(%{"comment-id" => comment_id}, socket) do
    with {:ok, pr} <- require_selected_pr(socket),
         {:ok, _updated} <-
           Pipeline.resolve_pull_request_thread(pr.number, comment_id, %{
             actor_id: actor_id(socket)
           }) do
      {:noreply, reload_pr_after_mutation(socket)}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def resolve_thread(_params, socket), do: {:noreply, socket}

  def select_review_decision(%{"event" => decision}, socket)
      when decision in ["approve", "request_changes", "comment"] do
    {:noreply, assign(socket, :pr_review_decision, decision)}
  end

  def select_review_decision(_params, socket), do: {:noreply, socket}

  def submit_review(%{"review" => %{"body" => body}}, socket) do
    with {:ok, pr} <- require_selected_pr(socket),
         {:ok, _updated} <-
           Pipeline.review_pull_request(pr.number, %{
             actor_id: actor_id(socket),
             event: socket.assigns[:pr_review_decision] || "comment",
             body: String.trim(body || "")
           }) do
      {:noreply, reload_pr_after_mutation(socket)}
    else
      {:error, reason} -> {:noreply, put_flash(socket, :error, format_error(reason))}
    end
  end

  def submit_review(_params, socket), do: {:noreply, socket}

  def start_inline_comment(_params, socket),
    do: {:noreply, assign(socket, :show_inline_comment_form, true)}

  def grouped_review_threads(nil), do: []

  def grouped_review_threads(pr) when is_map(pr) do
    comments = Map.get(pr, :comments, [])
    comments_by_id = Map.new(comments, &{&1.id, &1})

    roots =
      Enum.filter(comments, fn comment ->
        is_nil(comment.parent_comment_id) or
          !Map.has_key?(comments_by_id, comment.parent_comment_id)
      end)

    roots
    |> Enum.sort_by(&sort_key/1)
    |> Enum.map(fn root ->
      replies =
        comments
        |> Enum.filter(&(&1.parent_comment_id == root.id))
        |> Enum.sort_by(&sort_key/1)

      %{
        id: root.id,
        path: root.path,
        line: root.line,
        resolved: root.resolved,
        resolved_at: root.resolved_at,
        resolved_by: root.resolved_by,
        comments: [root | replies]
      }
    end)
  end

  def grouped_review_threads(_), do: []

  defp reload_pr_after_mutation(socket) do
    active_ticket_number = socket.assigns[:active_ticket_number]
    active_tab = socket.assigns[:active_session_tab] || "chat"
    load_pr_tab(socket, active_ticket_number, active_tab)
  end

  defp load_pr_content(socket, pr) when is_map(pr) do
    {diff_payload, pr_error} =
      case Pipeline.get_pull_request_diff(pr.number) do
        {:ok, %{diff: diff}} -> {diff, nil}
        {:error, reason} -> {"", reason}
      end

    socket
    |> assign(:pr_loading, false)
    |> assign(:pr_error, pr_error)
    |> assign(:pr_diff_payload, diff_payload)
    |> assign(:pr_review_threads, grouped_review_threads(pr))
    |> assign(:pr_review_decision, socket.assigns[:pr_review_decision] || "comment")
    |> assign(:show_inline_comment_form, socket.assigns[:show_inline_comment_form] || false)
    |> assign(:inline_comment_body, socket.assigns[:inline_comment_body] || "")
  end

  defp require_selected_pr(socket) do
    case socket.assigns[:selected_pull_request] do
      pr when is_map(pr) -> {:ok, pr}
      _ -> {:error, :pull_request_not_found}
    end
  end

  defp actor_id(socket), do: socket.assigns.current_scope.user.id

  defp format_error(:not_found), do: "Not found"
  defp format_error(:pull_request_not_found), do: "No linked pull request for this ticket"
  defp format_error({:git_diff_failed, _} = reason), do: inspect(reason)
  defp format_error(reason), do: inspect(reason)

  defp sort_key(comment) do
    timestamp = comment.inserted_at || ~U[1970-01-01 00:00:00Z]
    {DateTime.to_unix(timestamp, :microsecond), comment.id || ""}
  end
end
