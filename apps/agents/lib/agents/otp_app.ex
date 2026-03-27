defmodule Agents.OTPApp do
  @moduledoc """
  OTP Application for the Agents bounded context.

  Starts the perme8-mcp server alongside any other
  agent-related processes. Optionally starts a standalone Bandit HTTP
  server to expose the MCP endpoint when `:mcp_http` is configured.
  """
  use Application

  alias Agents.Sessions.Infrastructure.OrphanRecovery
  alias Agents.Sessions.Infrastructure.QueueOrchestratorSupervisor
  alias Agents.Sessions.Infrastructure.Subscribers.TicketSessionTerminationHandler
  alias Agents.Sessions.Infrastructure.TaskRunnerSupervisor
  alias Agents.Pipeline.Infrastructure.PipelineEventHandler
  alias Agents.Pipeline.Infrastructure.PipelineScheduler
  alias Agents.Tickets.Infrastructure.Subscribers.GithubTicketPushHandler
  alias Agents.Tickets.Infrastructure.TicketSyncServer

  @impl true
  def start(_type, _args) do
    children =
      [
        Agents.Repo,
        Hermes.Server.Registry,
        {Registry, keys: :unique, name: Agents.Sessions.TaskRegistry},
        {Registry, keys: :unique, name: Agents.Sessions.QueueRegistry}
      ] ++
        orphan_recovery_children() ++
        [
          TaskRunnerSupervisor,
          QueueOrchestratorSupervisor,
          TicketSessionTerminationHandler
        ] ++
        pipeline_children() ++
        ticket_infra_children() ++
        pipeline_scheduler_children() ++ mcp_children() ++ mcp_http_children()

    opts = [strategy: :one_for_one, name: Agents.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Recover tasks orphaned by a previous server restart.
  # Skipped in test mode to avoid Ecto sandbox and Mox ownership conflicts.
  defp orphan_recovery_children do
    if Application.get_env(:agents, :skip_orphan_recovery, false) do
      []
    else
      [{Task, fn -> OrphanRecovery.recover_orphaned_tasks() end}]
    end
  end

  defp mcp_children do
    transport = mcp_transport()

    [{Agents.Infrastructure.Mcp.Server, transport: transport}]
  end

  defp ticket_infra_children do
    []
    |> maybe_add_child(
      Application.get_env(:agents, :start_ticket_sync_server, true),
      TicketSyncServer
    )
    |> maybe_add_child(
      Application.get_env(:agents, :start_github_ticket_push_handler, true),
      GithubTicketPushHandler
    )
  end

  defp pipeline_children do
    maybe_add_child(
      [],
      Application.get_env(:agents, :start_pipeline_event_handler, true),
      PipelineEventHandler
    )
  end

  defp pipeline_scheduler_children do
    if Application.get_env(:agents, :pipeline_scheduler_enabled, false) do
      [PipelineScheduler]
    else
      []
    end
  end

  defp mcp_transport do
    Application.get_env(:agents, :mcp_transport, {:streamable_http, []})
  end

  # Starts a standalone Bandit HTTP server for the MCP router when configured.
  # Config example: config :agents, :mcp_http, port: 4007
  defp mcp_http_children do
    case Application.get_env(:agents, :mcp_http) do
      nil ->
        []

      opts when is_list(opts) ->
        port = Keyword.get(opts, :port, 4007)

        [
          {Bandit, plug: Agents.Infrastructure.Mcp.Router, port: port, scheme: :http}
        ]
    end
  end

  defp maybe_add_child(children, true, child), do: children ++ [child]
  defp maybe_add_child(children, false, _child), do: children
end
