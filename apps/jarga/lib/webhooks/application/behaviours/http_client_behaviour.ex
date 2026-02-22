defmodule Jarga.Webhooks.Application.Behaviours.HttpClientBehaviour do
  @moduledoc """
  Behaviour defining the interface for HTTP client operations.

  Used by webhook delivery use cases to send outbound HTTP POST requests.
  """

  @callback post(String.t(), map(), keyword()) :: {:ok, map()} | {:error, term()}
end
