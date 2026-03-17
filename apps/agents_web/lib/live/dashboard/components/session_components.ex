defmodule AgentsWeb.DashboardLive.Components.SessionComponents do
  @moduledoc """
  Delegation hub for dashboard session components.

  Re-exports all dashboard component functions for backward compatibility.
  Callers that `import AgentsWeb.DashboardLive.Components.SessionComponents`
  get access to all component functions without needing to know which
  sub-module defines them.

  Actual implementations live in:
  - `AgentsWeb.DashboardLive.Components.ChatOutputComponents`
  - `AgentsWeb.DashboardLive.Components.TicketCardComponent`
  """

  # -- ChatOutputComponents --
  defdelegate chat_part(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
  defdelegate output_part(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
  defdelegate queued_message(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
  defdelegate progress_bar(assigns), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents

  defdelegate compact_progress_bar(assigns),
    to: AgentsWeb.DashboardLive.Components.ChatOutputComponents

  defdelegate render_markdown(text), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents

  defdelegate format_tool_input(input),
    to: AgentsWeb.DashboardLive.Components.ChatOutputComponents

  defdelegate truncate_output(text), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents
  defdelegate format_mem_short(bytes), to: AgentsWeb.DashboardLive.Components.ChatOutputComponents

  # -- TicketCardComponent --
  defdelegate tab_bar(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent
  defdelegate question_card(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent
  defdelegate ticket_card(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent

  defdelegate lifecycle_timeline(assigns),
    to: AgentsWeb.DashboardLive.Components.TicketCardComponent

  defdelegate label_picker(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent

  defdelegate toggle_label(labels, label),
    to: AgentsWeb.DashboardLive.Components.TicketCardComponent

  defdelegate status_badge(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent
  defdelegate status_dot(assigns), to: AgentsWeb.DashboardLive.Components.TicketCardComponent

  defdelegate container_stats_bars(assigns),
    to: AgentsWeb.DashboardLive.Components.TicketCardComponent
end
