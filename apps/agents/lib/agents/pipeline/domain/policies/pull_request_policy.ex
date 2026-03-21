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
  def valid_transition?(from, to) when is_binary(from) and is_binary(to) do
    allowed = Map.get(@transitions, from, MapSet.new())

    if MapSet.member?(allowed, to), do: :ok, else: {:error, :invalid_transition}
  end

  def valid_transition?(_, _), do: {:error, :invalid_transition}
end
