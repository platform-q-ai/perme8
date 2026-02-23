defmodule Webhooks do
  @moduledoc """
  The Webhooks context facade.

  Provides the public API for outbound webhook subscriptions
  (event-driven HTTP POST dispatches with HMAC-SHA256 signing)
  and inbound webhook reception (signature verification and audit logging).
  """

  use Boundary,
    top_level?: true,
    deps: [
      Webhooks.Application,
      Webhooks.Repo
    ],
    exports: []

  alias Webhooks.Application.UseCases

  # --- Outbound Subscription Management ---

  @doc """
  Creates an outbound webhook subscription.

  Returns {:ok, subscription} with secret included (only time it's visible).
  """
  def create_subscription(user, api_key, workspace_slug, attrs, opts \\ []) do
    with {:ok, workspace, member} <- resolve_workspace(user, api_key, workspace_slug, opts) do
      params = %{
        workspace_id: workspace.id,
        member_role: member.role,
        url: Map.get(attrs, "url") || Map.get(attrs, :url),
        event_types: Map.get(attrs, "event_types") || Map.get(attrs, :event_types),
        created_by_id: user.id
      }

      UseCases.CreateSubscription.execute(params, use_case_opts(opts))
    end
  end

  @doc """
  Lists outbound webhook subscriptions for a workspace.
  """
  def list_subscriptions(user, api_key, workspace_slug, opts \\ []) do
    with {:ok, workspace, member} <- resolve_workspace(user, api_key, workspace_slug, opts) do
      params = %{workspace_id: workspace.id, member_role: member.role}
      UseCases.ListSubscriptions.execute(params, use_case_opts(opts))
    end
  end

  @doc """
  Gets a single outbound webhook subscription.
  """
  def get_subscription(user, api_key, workspace_slug, subscription_id, opts \\ []) do
    with {:ok, workspace, member} <- resolve_workspace(user, api_key, workspace_slug, opts) do
      params = %{
        workspace_id: workspace.id,
        member_role: member.role,
        subscription_id: subscription_id
      }

      UseCases.GetSubscription.execute(params, use_case_opts(opts))
    end
  end

  @doc """
  Updates an outbound webhook subscription.
  """
  def update_subscription(user, api_key, workspace_slug, subscription_id, attrs, opts \\ []) do
    with {:ok, workspace, member} <- resolve_workspace(user, api_key, workspace_slug, opts) do
      params = %{
        workspace_id: workspace.id,
        member_role: member.role,
        subscription_id: subscription_id,
        attrs: attrs
      }

      UseCases.UpdateSubscription.execute(params, use_case_opts(opts))
    end
  end

  @doc """
  Deletes an outbound webhook subscription.
  """
  def delete_subscription(user, api_key, workspace_slug, subscription_id, opts \\ []) do
    with {:ok, workspace, member} <- resolve_workspace(user, api_key, workspace_slug, opts) do
      params = %{
        workspace_id: workspace.id,
        member_role: member.role,
        subscription_id: subscription_id
      }

      UseCases.DeleteSubscription.execute(params, use_case_opts(opts))
    end
  end

  # --- Delivery Logs ---

  @doc """
  Lists delivery records for a subscription.
  """
  def list_deliveries(user, api_key, workspace_slug, subscription_id, opts \\ []) do
    with {:ok, workspace, member} <- resolve_workspace(user, api_key, workspace_slug, opts) do
      params = %{
        workspace_id: workspace.id,
        member_role: member.role,
        subscription_id: subscription_id
      }

      UseCases.ListDeliveries.execute(params, use_case_opts(opts))
    end
  end

  @doc """
  Gets a single delivery record with full details.
  """
  def get_delivery(user, api_key, workspace_slug, delivery_id, opts \\ []) do
    with {:ok, workspace, member} <- resolve_workspace(user, api_key, workspace_slug, opts) do
      params = %{
        workspace_id: workspace.id,
        member_role: member.role,
        delivery_id: delivery_id
      }

      UseCases.GetDelivery.execute(params, use_case_opts(opts))
    end
  end

  # --- Inbound Webhook Reception ---

  @doc """
  Receives an inbound webhook. Uses HMAC signature verification (not Bearer token).

  Does NOT require user/api_key auth -- the workspace_slug comes from the URL
  and we resolve it without membership check.
  """
  def receive_inbound_webhook(workspace_slug, raw_body, signature, source_ip, opts \\ []) do
    resolve_fn = Keyword.get(opts, :resolve_workspace_id, &Identity.resolve_workspace_id/1)

    case resolve_fn.(workspace_slug) do
      {:ok, workspace_id} ->
        params = %{
          workspace_id: workspace_id,
          raw_body: raw_body,
          signature: signature,
          source_ip: source_ip
        }

        UseCases.ReceiveInboundWebhook.execute(params, use_case_opts(opts))

      {:error, :not_found} ->
        {:error, :workspace_not_found}
    end
  end

  # --- Inbound Logs (authenticated) ---

  @doc """
  Lists inbound webhook audit logs for a workspace.
  """
  def list_inbound_logs(user, api_key, workspace_slug, opts \\ []) do
    with {:ok, workspace, member} <- resolve_workspace(user, api_key, workspace_slug, opts) do
      params = %{workspace_id: workspace.id, member_role: member.role}
      UseCases.ListInboundLogs.execute(params, use_case_opts(opts))
    end
  end

  # --- Private Helpers ---

  defp resolve_workspace(user, api_key, workspace_slug, opts) do
    if workspace_in_scope?(api_key, workspace_slug) do
      get_fn =
        Keyword.get(
          opts,
          :get_workspace_and_member_by_slug,
          &Identity.get_workspace_and_member_by_slug/2
        )

      case get_fn.(user, workspace_slug) do
        {:ok, workspace, member} -> {:ok, workspace, member}
        {:error, :workspace_not_found} -> {:error, :workspace_not_found}
        {:error, :unauthorized} -> {:error, :unauthorized}
      end
    else
      {:error, :forbidden}
    end
  end

  defp workspace_in_scope?(%{workspace_access: nil}, _slug), do: false
  defp workspace_in_scope?(%{workspace_access: []}, _slug), do: false
  defp workspace_in_scope?(%{workspace_access: access}, slug), do: slug in access

  defp use_case_opts(opts) do
    cleaned = Keyword.drop(opts, [:get_workspace_and_member_by_slug, :resolve_workspace_id])

    # Ensure :repo defaults to Webhooks.Repo so use cases don't pass nil
    # to repositories (which would override their default repo argument)
    Keyword.put_new(cleaned, :repo, Webhooks.Repo)
  end
end
