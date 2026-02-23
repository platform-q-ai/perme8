defmodule WebhooksApi.SubscriptionApiJSON do
  @moduledoc "JSON rendering for Subscription API endpoints."

  def created(%{subscription: subscription}) do
    %{data: subscription_data(subscription, include_secret: true)}
  end

  def show(%{subscription: subscription}) do
    %{data: subscription_data(subscription, include_secret: false)}
  end

  def index(%{subscriptions: subscriptions}) do
    %{data: Enum.map(subscriptions, &subscription_data(&1, include_secret: false))}
  end

  def deleted(%{}) do
    %{data: %{deleted: true}}
  end

  def validation_error(%{changeset: changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{errors: errors}
  end

  def error(%{message: message}) do
    %{error: message}
  end

  defp subscription_data(subscription, opts) do
    data = %{
      id: subscription.id,
      url: subscription.url,
      event_types: subscription.event_types,
      is_active: subscription.is_active,
      workspace_id: subscription.workspace_id,
      created_by_id: subscription.created_by_id
    }

    if Keyword.get(opts, :include_secret, false) and subscription.secret do
      Map.put(data, :secret, subscription.secret)
    else
      data
    end
  end
end
