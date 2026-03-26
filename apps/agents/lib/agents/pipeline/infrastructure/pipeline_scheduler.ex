defmodule Agents.Pipeline.Infrastructure.PipelineScheduler do
  @moduledoc """
  Cron-driven event source for scheduled pipeline flows.
  """

  use GenServer

  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.Application.UseCases.TriggerPipelineRun

  require Logger

  @default_fallback_interval_ms :timer.minutes(5)
  @scheduled_trigger "on_warm_pool"

  @doc "Starts the pipeline scheduler process."
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    state = %{trigger_pipeline_run: Keyword.get(opts, :trigger_pipeline_run, TriggerPipelineRun)}
    schedule_tick(state)
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    trigger_scheduled_flow(state)
    schedule_tick(state)
    {:noreply, state}
  end

  defp trigger_scheduled_flow(state) do
    case state.trigger_pipeline_run.execute(%{
           trigger_type: @scheduled_trigger,
           trigger_reference: "scheduler"
         }) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        Logger.warning("PipelineScheduler scheduled trigger failed: #{inspect(reason)}")
    end
  end

  defp schedule_tick(state) do
    Process.send_after(self(), :tick, interval_ms(state))
  end

  defp interval_ms(_state) do
    with {:ok, config} <- LoadPipeline.execute(),
         intervals when intervals != [] <- scheduled_intervals(config.stages) do
      Enum.min(intervals)
    else
      _ -> @default_fallback_interval_ms
    end
  end

  defp scheduled_intervals(stages) do
    stages
    |> Enum.filter(&(@scheduled_trigger in (&1.triggers || [])))
    |> Enum.map(&cron_from_stage/1)
    |> Enum.flat_map(fn
      {:ok, interval_ms} -> [interval_ms]
      _ -> []
    end)
  end

  defp cron_from_stage(stage) do
    case stage.schedule && Map.get(stage.schedule, "cron") do
      cron when is_binary(cron) -> cron_to_interval_ms(cron)
      _ -> {:error, :missing_cron}
    end
  end

  defp cron_to_interval_ms("* * * * *"), do: {:ok, :timer.minutes(1)}

  defp cron_to_interval_ms(cron) do
    case Regex.run(~r/^\*\/(\d+) \* \* \* \*$/, cron) do
      [_, minutes] -> {:ok, :timer.minutes(String.to_integer(minutes))}
      _ -> {:error, :unsupported_cron_expression}
    end
  end
end
