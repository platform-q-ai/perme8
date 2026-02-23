defmodule Webhooks.Infrastructure.Workers.RetryWorker do
  @moduledoc """
  GenServer that periodically polls for pending webhook delivery retries
  and dispatches each one via the RetryDelivery use case.

  Polls every 30 seconds by default. Dependencies are injectable via opts.
  """

  use GenServer

  require Logger

  @default_poll_interval 30_000

  @default_delivery_repo_fn &Webhooks.Infrastructure.Repositories.DeliveryRepository.list_pending_retries/1
  @default_retry_fn &Webhooks.Application.UseCases.RetryDelivery.execute/2
  @default_repo Webhooks.Repo

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    delivery_repo_fn = Keyword.get(opts, :delivery_repo_fn, @default_delivery_repo_fn)
    retry_fn = Keyword.get(opts, :retry_fn, @default_retry_fn)
    repo = Keyword.get(opts, :repo, @default_repo)

    state = %{
      poll_interval: poll_interval,
      delivery_repo_fn: delivery_repo_fn,
      retry_fn: retry_fn,
      repo: repo
    }

    schedule_poll(poll_interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    poll_and_retry(state)
    schedule_poll(state.poll_interval)
    {:noreply, state}
  end

  defp poll_and_retry(state) do
    case state.delivery_repo_fn.(state.repo) do
      {:ok, deliveries} ->
        Enum.each(deliveries, fn delivery ->
          try do
            state.retry_fn.(%{delivery: delivery}, repo: state.repo)
          rescue
            e ->
              Logger.error("RetryWorker failed to retry delivery #{delivery.id}: #{inspect(e)}")
          end
        end)

      {:error, reason} ->
        Logger.error("RetryWorker failed to fetch pending retries: #{inspect(reason)}")
    end
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end
end
