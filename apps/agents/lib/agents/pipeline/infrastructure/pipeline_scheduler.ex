defmodule Agents.Pipeline.Infrastructure.PipelineScheduler do
  @moduledoc """
  Cron-driven scheduler for warm-pool replenishment.
  """

  use GenServer

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.Application.UseCases.ReplenishWarmPool

  require Logger

  @default_fallback_interval_ms :timer.minutes(5)

  @doc "Starts the warm-pool scheduler process."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    state = %{
      pipeline_path: Keyword.get(opts, :pipeline_path),
      pipeline_parser:
        Keyword.get(opts, :pipeline_parser, PipelineRuntimeConfig.pipeline_parser()),
      stage_executor: Keyword.get(opts, :stage_executor, PipelineRuntimeConfig.stage_executor()),
      warm_pool_counter:
        Keyword.get(opts, :warm_pool_counter, PipelineRuntimeConfig.warm_pool_counter()),
      replenish_warm_pool: Keyword.get(opts, :replenish_warm_pool, ReplenishWarmPool)
    }

    schedule_tick(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    run_replenishment(state)
    schedule_tick(state)
    {:noreply, state}
  end

  defp run_replenishment(state) do
    opts =
      []
      |> maybe_put(:pipeline_path, state.pipeline_path)
      |> maybe_put(:pipeline_parser, state.pipeline_parser)
      |> maybe_put(:stage_executor, state.stage_executor)
      |> maybe_put(:warm_pool_counter, state.warm_pool_counter)

    case state.replenish_warm_pool.execute(opts) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        Logger.warning("PipelineScheduler warm-pool replenish failed: #{inspect(reason)}")
    end
  end

  defp schedule_tick(state) do
    Process.send_after(self(), :tick, interval_ms(state))
  end

  defp interval_ms(state) do
    with parser when not is_nil(parser) <- state.pipeline_parser,
         {:ok, config} <-
           LoadPipeline.execute(state.pipeline_path,
             parser: parser,
             pipeline_source: :auto
           ),
         stage when not is_nil(stage) <-
           Enum.find(config.stages, &(&1.type == "warm_pool" or &1.id == "warm-pool")),
         cron when is_binary(cron) <- stage.schedule && Map.get(stage.schedule, "cron"),
         {:ok, interval_ms} <- cron_to_interval_ms(cron) do
      interval_ms
    else
      _ -> @default_fallback_interval_ms
    end
  end

  defp cron_to_interval_ms("* * * * *"), do: {:ok, :timer.minutes(1)}

  defp cron_to_interval_ms(cron) do
    case Regex.run(~r/^\*\/(\d+) \* \* \* \*$/, cron) do
      [_, minutes] -> {:ok, :timer.minutes(String.to_integer(minutes))}
      _ -> {:error, :unsupported_cron_expression}
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
