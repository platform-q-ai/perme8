defmodule Agents.Pipeline.Domain.Policies.PipelineLifecyclePolicy do
  @moduledoc "State machine for pipeline execution runs."

  @transitions %{
    "idle" => ["running_stage"],
    "running_stage" => ["awaiting_result"],
    "awaiting_result" => ["passed", "failed"],
    "passed" => ["running_stage", "deploy"],
    "failed" => ["reopen_session"],
    "deploy" => ["running_stage", "passed"],
    "reopen_session" => []
  }

  @spec valid_transition?(String.t(), String.t()) :: :ok | {:error, :invalid_transition}
  def valid_transition?(from, to) when is_binary(from) and is_binary(to) do
    if to in Map.get(@transitions, from, []) do
      :ok
    else
      {:error, :invalid_transition}
    end
  end

  @spec transition(String.t(), String.t()) :: {:ok, String.t()} | {:error, :invalid_transition}
  def transition(from, to) do
    case valid_transition?(from, to) do
      :ok -> {:ok, to}
      error -> error
    end
  end
end
