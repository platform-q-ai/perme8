defmodule Jarga.Webhooks.Application.UseCases.CreateWebhookSubscription do
  @moduledoc """
  Use case for creating a webhook subscription.

  ## Business Rules

  - Actor must be an admin or owner of the workspace
  - Auto-generates a signing secret for HMAC verification
  - Emits WebhookSubscriptionCreated domain event on success

  ## Dependencies (injectable via opts)

  - `:webhook_repository` - persistence
  - `:event_bus` - domain event emission
  - `:membership_checker` - workspace membership verification
  """

  alias Jarga.Webhooks.Domain.Events.WebhookSubscriptionCreated
  alias Jarga.Webhooks.Domain.Policies.WebhookPolicy

  @default_webhook_repository Jarga.Webhooks.Infrastructure.Repositories.WebhookRepository
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Creates a webhook subscription for a workspace.

  ## Parameters

  - `params` - Map with `:actor`, `:workspace_id`, `:attrs`
  - `opts` - Keyword list for DI

  ## Returns

  - `{:ok, subscription}` on success
  - `{:error, :forbidden}` if actor lacks permission
  - `{:error, :unauthorized}` if actor is not a workspace member
  - `{:error, changeset}` on validation failure
  """
  def execute(params, opts \\ []) do
    %{actor: actor, workspace_id: workspace_id, attrs: attrs} = params

    webhook_repository = Keyword.get(opts, :webhook_repository, @default_webhook_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])
    membership_checker = Keyword.get(opts, :membership_checker, &default_membership_checker/2)

    with {:ok, member} <- membership_checker.(actor, workspace_id),
         :ok <- authorize(member.role) do
      secret = generate_secret()
      insert_attrs = build_insert_attrs(attrs, workspace_id, actor.id, secret)

      case webhook_repository.insert(insert_attrs, opts) do
        {:ok, subscription} ->
          emit_event(subscription, actor, workspace_id, event_bus, event_bus_opts)
          {:ok, subscription}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp authorize(role) do
    if WebhookPolicy.can_manage_webhooks?(role), do: :ok, else: {:error, :forbidden}
  end

  defp generate_secret do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp build_insert_attrs(attrs, workspace_id, created_by_id, secret) do
    attrs
    |> Map.put(:workspace_id, workspace_id)
    |> Map.put(:created_by_id, created_by_id)
    |> Map.put(:secret, secret)
  end

  defp emit_event(subscription, actor, workspace_id, event_bus, event_bus_opts) do
    event =
      WebhookSubscriptionCreated.new(%{
        aggregate_id: subscription.id,
        actor_id: actor.id,
        workspace_id: workspace_id,
        url: subscription.url,
        event_types: subscription.event_types || []
      })

    event_bus.emit(event, event_bus_opts)
  end

  defp default_membership_checker(actor, workspace_id) do
    Jarga.Workspaces.get_member(actor, workspace_id)
  end
end
