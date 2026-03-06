defmodule AgentsWeb.SessionsLive.SdkFieldResolver do
  @moduledoc """
  Centralizes SDK field name resolution for the opencode event stream.

  The SDK uses multiple naming conventions for the same concept
  (camelCase, snake_case, mixed). This module provides a single point
  of resolution so event processing code doesn't need scattered
  fallback chains.
  """

  @doc """
  Resolves the message ID from an event info or part map.

  Prefers explicit message ID fields (`messageID`, `messageId`) over the
  generic `id` field, because `id` may refer to a different entity
  (e.g., part ID in `message.part.updated` events).
  """
  @spec resolve_message_id(map()) :: String.t() | nil
  def resolve_message_id(map) do
    map["messageID"] || map["messageId"] || map["id"]
  end

  @doc "Resolves the correlation key from an event info map."
  @spec resolve_correlation_key(map()) :: String.t() | nil
  def resolve_correlation_key(map) do
    map["correlationKey"] || map["correlation_key"] || map["correlationID"]
  end

  @doc "Resolves the tool call ID from a part map."
  @spec resolve_tool_call_id(map()) :: String.t() | nil
  def resolve_tool_call_id(map) do
    map["id"] || map["toolCallID"] || map["toolCallId"] || map["callID"]
  end

  @doc "Resolves the model ID from an event info map."
  @spec resolve_model_id(map()) :: String.t() | nil
  def resolve_model_id(map) do
    map["modelID"] || map["modelId"] || map["model_id"]
  end
end
