defmodule Agents.Pipeline.Domain.Policies.PullRequestPolicy do
  @moduledoc "Pure business rules for internal pull request status transitions."

  @transitions %{
    "draft" => MapSet.new(["open", "closed"]),
    "open" => MapSet.new(["in_review", "closed"]),
    "in_review" => MapSet.new(["approved", "open", "closed"]),
    "approved" => MapSet.new(["merged", "in_review", "closed"]),
    "merged" => MapSet.new(),
    "closed" => MapSet.new()
  }

  @spec valid_transition?(String.t(), String.t()) :: :ok | {:error, :invalid_transition}
  def valid_transition?(current_status, next_status)
      when is_binary(current_status) and is_binary(next_status) do
    allowed = Map.get(@transitions, current_status, MapSet.new())

    if MapSet.member?(allowed, next_status), do: :ok, else: {:error, :invalid_transition}
  end

  def valid_transition?(_, _), do: {:error, :invalid_transition}
end
