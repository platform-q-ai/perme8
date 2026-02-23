defmodule WebhooksApi.DeliveryApiJSON do
  @moduledoc "JSON rendering for Delivery API endpoints."

  def index(%{deliveries: deliveries}) do
    %{data: Enum.map(deliveries, &delivery_summary/1)}
  end

  def show(%{delivery: delivery}) do
    %{data: delivery_detail(delivery)}
  end

  def error(%{message: message}) do
    %{error: message}
  end

  defp delivery_summary(delivery) do
    %{
      id: delivery.id,
      event_type: delivery.event_type,
      status: delivery.status,
      response_code: delivery.response_code,
      inserted_at: delivery.inserted_at
    }
  end

  defp delivery_detail(delivery) do
    base = %{
      id: delivery.id,
      subscription_id: delivery.subscription_id,
      event_type: delivery.event_type,
      payload: delivery.payload,
      status: delivery.status,
      response_code: delivery.response_code,
      response_body: delivery.response_body,
      attempts: delivery.attempts,
      inserted_at: delivery.inserted_at
    }

    if delivery.next_retry_at do
      Map.put(base, :next_retry_at, delivery.next_retry_at)
    else
      base
    end
  end
end
