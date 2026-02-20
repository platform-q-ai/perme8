defmodule ExoDashboardWeb.ResultComponents do
  @moduledoc """
  UI components for displaying test run results.
  """
  use Phoenix.Component

  @doc """
  Renders a status badge.
  """
  attr(:status, :atom, required: true)

  def status_badge(assigns) do
    {color, label} = status_style(assigns.status)
    assigns = assign(assigns, color: color, label: label)

    ~H"""
    <span class={"badge badge-sm #{@color}"} data-status={@status}>
      {@label}
    </span>
    """
  end

  @doc """
  Renders a single step result row.
  """
  attr(:step, :map, required: true)

  def step_result(assigns) do
    ~H"""
    <div class="flex items-center gap-2 py-1 text-sm" data-step-status={@step.status}>
      <.status_badge status={@step.status} />
      <span class="text-base-content/80">{@step[:test_step_id]}</span>
      <span :if={@step[:duration_ms]} class="text-xs text-base-content/50 ml-auto">
        {@step[:duration_ms]}ms
      </span>
    </div>
    """
  end

  @doc """
  Renders a progress bar for a test run.
  """
  attr(:progress, :map, required: true)

  def progress_bar(assigns) do
    total = assigns.progress[:total] || 0
    passed = assigns.progress[:passed] || 0
    failed = assigns.progress[:failed] || 0

    passed_pct = if total > 0, do: Float.round(passed / total * 100, 1), else: 0
    failed_pct = if total > 0, do: Float.round(failed / total * 100, 1), else: 0

    assigns =
      assign(assigns,
        total: total,
        passed: passed,
        failed: failed,
        passed_pct: passed_pct,
        failed_pct: failed_pct
      )

    ~H"""
    <div class="w-full" data-testid="progress-bar">
      <div class="flex gap-2 text-xs text-base-content/70 mb-1">
        <span class="text-success">{@passed} passed</span>
        <span :if={@failed > 0} class="text-error">{@failed} failed</span>
        <span class="ml-auto">{@passed + @failed} / {@total}</span>
      </div>
      <div class="w-full bg-base-300 rounded-full h-2">
        <div class="flex h-full rounded-full overflow-hidden">
          <div class="bg-success h-full" style={"width: #{@passed_pct}%"}></div>
          <div class="bg-error h-full" style={"width: #{@failed_pct}%"}></div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a run summary card.
  """
  attr(:run, :map, required: true)

  def run_summary(assigns) do
    ~H"""
    <div class="card bg-base-200 p-4" data-testid="run-summary">
      <div class="flex items-center justify-between mb-2">
        <span class="font-semibold text-sm">Run {@run.id |> String.slice(0..7)}</span>
        <.status_badge status={@run.status} />
      </div>
      <.progress_bar progress={@run.progress} />
    </div>
    """
  end

  defp status_style(:passed), do: {"badge-success", "Passed"}
  defp status_style(:failed), do: {"badge-error", "Failed"}
  defp status_style(:running), do: {"badge-info", "Running"}
  defp status_style(:pending), do: {"badge-warning", "Pending"}
  defp status_style(:skipped), do: {"badge-ghost", "Skipped"}
  defp status_style(_), do: {"badge-ghost", "Unknown"}
end
