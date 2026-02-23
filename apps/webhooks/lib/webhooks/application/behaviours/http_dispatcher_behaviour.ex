defmodule Webhooks.Application.Behaviours.HttpDispatcherBehaviour do
  @moduledoc """
  Behaviour defining the HTTP dispatcher contract for outbound webhooks.

  Implementations handle the actual HTTP POST dispatch to webhook URLs.
  """

  @callback dispatch(
              url :: String.t(),
              payload_json :: String.t(),
              headers :: [{String.t(), String.t()}]
            ) ::
              {:ok, status_code :: integer(), response_body :: String.t()}
              | {:error, term()}
end
