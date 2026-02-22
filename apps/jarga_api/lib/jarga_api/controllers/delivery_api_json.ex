defmodule JargaApi.DeliveryApiJSON do
  @moduledoc """
  JSON rendering for Delivery API endpoints.
  """

  @doc """
  Renders a list of deliveries.
  """
  def index(%{deliveries: deliveries}) do
    %{data: Enum.map(deliveries, &delivery_data/1)}
  end

  @doc """
  Renders a single delivery.
  """
  def show(%{delivery: delivery}) do
    %{data: delivery_data(delivery)}
  end

  @doc """
  Renders an error message.
  """
  def error(%{message: message}) do
    %{error: message}
  end

  defp delivery_data(delivery) do
    %{
      id: delivery.id,
      event_type: delivery.event_type,
      status: delivery.status,
      response_code: delivery.response_code,
      attempts: delivery.attempts,
      max_attempts: delivery.max_attempts,
      next_retry_at: delivery.next_retry_at,
      payload: delivery.payload,
      inserted_at: delivery.inserted_at,
      updated_at: delivery.updated_at
    }
  end
end
