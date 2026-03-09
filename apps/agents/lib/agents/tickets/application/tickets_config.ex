defmodule Agents.Tickets.Application.TicketsConfig do
  @moduledoc """
  Configuration accessor for the Tickets bounded context.

  Reads from `Application.get_env(:agents, :sessions)`.
  """

  @doc "Returns whether GitHub ticket sync is enabled."
  def github_sync_enabled? do
    config()[:github_sync_enabled] != false
  end

  @doc "Returns the GitHub org/owner for issue queries."
  def github_org do
    config()[:github_org] || config()[:github_project_org] || "platform-q-ai"
  end

  @doc "Returns the GitHub repository name for issue queries."
  def github_repo do
    config()[:github_repo] || "perme8"
  end

  @doc "Returns GitHub sync polling interval in milliseconds."
  def github_poll_interval_ms do
    config()[:github_poll_interval_ms] || 15_000
  end

  @doc "Returns the GitHub token used for API queries."
  def github_token do
    config()[:github_token]
  end

  @doc "Returns the PubSub server name for broadcasting task events."
  def pubsub do
    config()[:pubsub] || Perme8.Events.PubSub
  end

  defp config do
    Application.get_env(:agents, :sessions, [])
  end
end
