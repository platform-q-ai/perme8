defmodule AgentsApi.GithubWebhookConfig do
  @moduledoc false

  def secret do
    config()[:secret]
  end

  defp config do
    Application.get_env(:agents, :github_webhook, [])
  end
end
