defmodule Agents.Pipeline.Domain.Policies.WarmPoolPolicy do
  @moduledoc """
  Pure policy helpers for warm-pool stage configuration.
  """

  alias Agents.Pipeline.Domain.Entities.Stage

  @type t :: %__MODULE__{
          stage_id: String.t(),
          cron: String.t(),
          target_count: non_neg_integer(),
          image: String.t(),
          readiness_criteria: map()
        }

  defstruct [:stage_id, :cron, :target_count, :image, readiness_criteria: %{}]

  @doc "Builds a warm-pool policy from a parsed warm-pool stage."
  @spec from_stage(Stage.t()) :: {:ok, t()} | {:error, term()}
  def from_stage(%Stage{type: "warm_pool", id: stage_id, schedule: schedule, config: config}) do
    warm_pool = Map.get(config, "warm_pool", %{})
    cron = cron_from_schedule(schedule)
    target_count = Map.get(warm_pool, "target_count")
    image = Map.get(warm_pool, "image")
    readiness = Map.get(warm_pool, "readiness")

    with :ok <- validate_cron(cron),
         :ok <- validate_target_count(target_count),
         :ok <- validate_image(image),
         :ok <- validate_readiness(readiness) do
      {:ok,
       %__MODULE__{
         stage_id: stage_id,
         cron: cron,
         target_count: target_count,
         image: image,
         readiness_criteria: readiness
       }}
    end
  end

  def from_stage(%Stage{}), do: {:error, :not_warm_pool_stage}

  @doc "Returns how many additional warm instances are needed to reach target capacity."
  @spec shortage(t(), non_neg_integer()) :: non_neg_integer()
  def shortage(%__MODULE__{target_count: target_count}, current_count)
      when is_integer(current_count) and current_count >= 0 do
    max(target_count - current_count, 0)
  end

  @doc "Returns true when the current warm count is below the configured target."
  @spec replenishment_required?(t(), non_neg_integer()) :: boolean()
  def replenishment_required?(%__MODULE__{} = policy, current_count) do
    shortage(policy, current_count) > 0
  end

  defp cron_from_schedule(schedule) when is_map(schedule), do: Map.get(schedule, "cron")
  defp cron_from_schedule(_), do: nil

  defp validate_cron(cron) when is_binary(cron) and cron != "", do: :ok
  defp validate_cron(_), do: {:error, :missing_cron}

  defp validate_target_count(target_count) when is_integer(target_count) and target_count >= 0,
    do: :ok

  defp validate_target_count(_), do: {:error, :invalid_target_count}

  defp validate_image(image) when is_binary(image) and image != "", do: :ok
  defp validate_image(_), do: {:error, :missing_image}

  defp validate_readiness(readiness) when is_map(readiness), do: :ok
  defp validate_readiness(_), do: {:error, :invalid_readiness_criteria}
end
