defmodule AgentsWeb.DashboardLive.Components.PRComponents do
  @moduledoc "Function components for the dashboard PR tab panel."

  use Phoenix.Component

  import AgentsWeb.DashboardLive.Components.SessionComponents, only: [render_markdown: 1]

  def parse_unified_diff(diff) when is_binary(diff) do
    case String.trim(diff) do
      "" ->
        [%{path: "No local diff available", body: ""}]

      text ->
        text
        |> String.split("diff --git ", trim: true)
        |> Enum.map(fn chunk ->
          lines = String.split(chunk, "\n")
          first = List.first(lines) || ""

          path =
            case String.split(first, " b/") do
              [_left, right] when is_binary(right) and right != "" -> right
              _ -> "unknown"
            end

          %{path: path, body: Enum.join(lines, "\n")}
        end)
    end
  end

  def parse_unified_diff(_), do: [%{path: "No local diff available", body: ""}]

  def review_outcome_label("approve"), do: "Approved"
  def review_outcome_label("request_changes"), do: "Changes requested"
  def review_outcome_label("comment"), do: "Commented"
  def review_outcome_label(_), do: "No reviews yet"

  attr(:selected_pull_request, :map, required: true)

  def pr_header(assigns) do
    ~H"""
    <div class="space-y-2">
      <h3 class="text-lg font-semibold" data-testid="pr-title">{@selected_pull_request.title}</h3>
      <div class="text-xs text-base-content/70" data-testid="pr-status">
        Status: {@selected_pull_request.status}
      </div>
      <div class="text-xs text-base-content/70" data-testid="pr-branches">
        {@selected_pull_request.source_branch} -> {@selected_pull_request.target_branch}
      </div>
      <div class="text-xs text-base-content/70" data-testid="pr-author-and-timestamps">
        Author: {pr_author(@selected_pull_request)} · Opened: {format_timestamp(
          @selected_pull_request.inserted_at
        )}
      </div>
    </div>
    """
  end

  attr(:selected_pull_request, :map, required: true)

  def pr_description(assigns) do
    ~H"""
    <div class="session-markdown text-sm" data-testid="pr-description">
      {render_markdown(@selected_pull_request.body || "")}
    </div>
    """
  end

  attr(:pr_diff_payload, :any, required: true)

  def pr_diff(assigns) do
    files = parse_unified_diff(assigns.pr_diff_payload)
    assigns = assign(assigns, :diff_files, files)

    ~H"""
    <div class="space-y-3">
      <div
        :for={file <- @diff_files}
        class="rounded border border-base-300 p-2"
        data-testid="pr-diff-file"
      >
        <div class="text-xs font-semibold mb-1">{file.path}</div>
        <pre class="text-xs overflow-x-auto" data-testid="pr-diff-code"><code>{file.body}</code></pre>
      </div>
    </div>
    """
  end

  attr(:threads, :list, required: true)

  def pr_threads(assigns) do
    ~H"""
    <div class="space-y-3">
      <div
        :for={thread <- @threads}
        data-testid="pr-review-thread"
        class={[
          "rounded border border-base-300 p-2 space-y-2",
          thread.resolved && "resolved bg-success/5 border-success/40"
        ]}
      >
        <div class="text-xs text-base-content/60" data-testid="pr-thread-resolved-state">
          <%= if thread.resolved do %>
            resolved
          <% else %>
            unresolved
          <% end %>
        </div>

        <div :for={comment <- thread.comments} class="text-sm">
          <div class="text-xs text-base-content/50">{comment.author_id}</div>
          <div>{comment.body}</div>
        </div>

        <form id={"pr-reply-form-#{thread.id}"} phx-submit="pr_reply_to_thread">
          <input type="hidden" name="comment_id" value={thread.id} />
          <textarea
            name="reply[body]"
            class="textarea textarea-bordered textarea-sm w-full"
            data-testid="pr-reply-input"
          ></textarea>
          <div class="mt-1 flex gap-2">
            <button type="submit" class="btn btn-xs">Reply</button>
            <button
              type="button"
              class="btn btn-xs btn-ghost"
              phx-click="pr_resolve_thread"
              phx-value-comment-id={thread.id}
              data-testid="pr-resolve-thread-button"
            >
              Resolve
            </button>
          </div>
        </form>
      </div>
      <div :if={@threads == []} class="text-xs text-base-content/60">No review threads yet.</div>
    </div>
    """
  end

  attr(:selected_pull_request, :map, required: true)
  attr(:pr_review_decision, :string, required: true)

  def pr_review_actions(assigns) do
    last_review = List.first(Enum.reverse(assigns.selected_pull_request.reviews || []))
    assigns = assign(assigns, :last_review, last_review)

    ~H"""
    <div class="space-y-2">
      <div class="flex gap-2">
        <button
          type="button"
          phx-click="pr_select_review_decision"
          phx-value-event="approve"
          data-testid="pr-review-decision-approve"
          class={decision_button_class(@pr_review_decision == "approve")}
        >
          Approve
        </button>
        <button
          type="button"
          phx-click="pr_select_review_decision"
          phx-value-event="request_changes"
          data-testid="pr-review-decision-request-changes"
          class={decision_button_class(@pr_review_decision == "request_changes")}
        >
          Request changes
        </button>
        <button
          type="button"
          phx-click="pr_select_review_decision"
          phx-value-event="comment"
          data-testid="pr-review-decision-comment"
          class={decision_button_class(@pr_review_decision == "comment")}
        >
          Comment
        </button>
      </div>

      <form id="pr-submit-review-form" phx-submit="pr_submit_review">
        <textarea name="review[body]" class="textarea textarea-bordered textarea-sm w-full"></textarea>
        <button type="submit" class="btn btn-sm mt-1">Submit review</button>
      </form>

      <div class="text-xs text-base-content/70" data-testid="pr-last-review-outcome">
        {review_outcome_label(@last_review && @last_review.event)}
      </div>
    </div>
    """
  end

  defp format_timestamp(nil), do: "-"

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  defp pr_author(pr) do
    first_comment_author =
      pr.comments
      |> List.first()
      |> case do
        nil -> nil
        comment -> comment.author_id
      end

    first_review_author =
      pr.reviews
      |> List.first()
      |> case do
        nil -> nil
        review -> review.author_id
      end

    first_comment_author || first_review_author || "Unknown"
  end

  defp decision_button_class(true), do: "btn btn-xs btn-primary"
  defp decision_button_class(false), do: "btn btn-xs btn-outline"
end
