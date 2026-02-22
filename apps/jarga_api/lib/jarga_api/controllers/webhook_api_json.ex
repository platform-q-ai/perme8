defmodule JargaApi.WebhookApiJSON do
  @moduledoc """
  JSON rendering for Webhook Subscription API endpoints.
  """

  @doc """
  Renders a list of webhook subscriptions.
  """
  def index(%{subscriptions: subscriptions}) do
    %{data: Enum.map(subscriptions, &subscription_data/1)}
  end

  @doc """
  Renders a single webhook subscription.
  """
  def show(%{subscription: subscription}) do
    %{data: subscription_data(subscription)}
  end

  @doc """
  Renders a deleted webhook subscription.
  """
  def deleted(%{subscription: subscription}) do
    %{data: %{id: subscription.id, deleted: true}}
  end

  @doc """
  Renders a validation error.
  """
  def validation_error(%{changeset: changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{errors: errors}
  end

  @doc """
  Renders an error message.
  """
  def error(%{message: message}) do
    %{error: message}
  end

  defp subscription_data(subscription) do
    %{
      id: subscription.id,
      url: subscription.url,
      secret: subscription.secret,
      event_types: subscription.event_types,
      is_active: subscription.is_active,
      inserted_at: subscription.inserted_at,
      updated_at: subscription.updated_at
    }
  end
end
