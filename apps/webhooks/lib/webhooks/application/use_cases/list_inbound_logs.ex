defmodule Webhooks.Application.UseCases.ListInboundLogs do
  @moduledoc """
  Use case for listing inbound webhook audit logs for a workspace.
  """

  @behaviour Webhooks.Application.UseCases.UseCase

  alias Webhooks.Domain.Policies.WebhookAuthorizationPolicy

  @default_log_repository Webhooks.Infrastructure.Repositories.InboundLogRepository

  @impl true
  def execute(params, opts \\ []) do
    %{workspace_id: workspace_id, member_role: member_role} = params

    log_repository =
      Keyword.get(opts, :inbound_log_repository, @default_log_repository)

    repo = Keyword.get(opts, :repo, nil)

    with :ok <- authorize(member_role) do
      log_repository.list_for_workspace(workspace_id, repo)
    end
  end

  defp authorize(role) do
    if WebhookAuthorizationPolicy.can_manage_webhooks?(role),
      do: :ok,
      else: {:error, :forbidden}
  end
end
