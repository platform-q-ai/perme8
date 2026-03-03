defmodule Agents.Sessions.Application.GithubWebhookConfig do
  @moduledoc """
  Runtime configuration accessor for GitHub webhook automation.
  """

  alias Agents.Sessions.Application.SessionsConfig

  @doc "Returns whether webhook automation is enabled."
  def enabled? do
    config()[:enabled] == true
  end

  @doc "Returns the configured GitHub webhook secret."
  def secret do
    config()[:secret]
  end

  @doc "Returns the user ID used to create automated agent tasks."
  def automation_user_id do
    config()[:automation_user_id]
  end

  @doc "Returns the repository slug handled by webhook automation."
  def repo do
    config()[:repo] || "platform-q-ai/perme8"
  end

  @doc "Returns the Docker image used for webhook-triggered sessions."
  def image do
    config()[:image] || SessionsConfig.image()
  end

  @doc "Returns the Git identity label expected inside automation sessions."
  def bot_identity do
    config()[:bot_identity] || "perme8[bot]"
  end

  defp config do
    Application.get_env(:agents, :github_webhook, [])
  end
end
