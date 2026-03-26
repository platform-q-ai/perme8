defmodule Agents.Pipeline.Domain.Policies.PipelineLifecyclePolicy do
  @moduledoc "State machine for pipeline execution runs."

  @transitions %{
    "idle" => ["running_stage"],
    "running_stage" => ["awaiting_result"],
    "awaiting_result" => ["passed", "blocked", "failed"],
    "passed" => ["running_stage"],
    "blocked" => ["running_stage", "failed"],
    "failed" => ["reopen_session"],
    "reopen_session" => []
  }

  @spec valid_transition?(String.t(), String.t()) :: :ok | {:error, :invalid_transition}
  def valid_transition?(current_status, next_status)
      when is_binary(current_status) and is_binary(next_status) do
    if next_status in Map.get(@transitions, current_status, []) do
      :ok
    else
      {:error, :invalid_transition}
    end
  end

  @spec transition(String.t(), String.t()) :: {:ok, String.t()} | {:error, :invalid_transition}
  def transition(current_status, next_status) do
    case valid_transition?(current_status, next_status) do
      :ok -> {:ok, next_status}
      error -> error
    end
  end
end
