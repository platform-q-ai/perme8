defmodule Webhooks.Infrastructure.Workers.RetryWorkerTest do
  use ExUnit.Case, async: false

  alias Webhooks.Infrastructure.Workers.RetryWorker
  alias Webhooks.Domain.Entities.Delivery

  describe "start_link/1" do
    test "worker starts successfully" do
      # Use mock functions that do nothing
      delivery_repo = fn _repo -> {:ok, []} end
      retry_fn = fn _params, _opts -> {:ok, %Delivery{}} end

      {:ok, pid} =
        RetryWorker.start_link(
          name: :"test_retry_worker_#{:erlang.unique_integer([:positive])}",
          delivery_repo_fn: delivery_repo,
          retry_fn: retry_fn,
          poll_interval: 60_000
        )

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "handle_info(:poll, state)" do
    test "polls for pending retries and dispatches RetryDelivery for each" do
      test_pid = self()

      delivery1 = %Delivery{
        id: "del-1",
        subscription_id: "sub-1",
        event_type: "projects.project_created",
        payload: %{},
        status: "pending",
        attempts: 1,
        next_retry_at: DateTime.add(DateTime.utc_now(), -60, :second)
      }

      delivery2 = %Delivery{
        id: "del-2",
        subscription_id: "sub-2",
        event_type: "documents.document_created",
        payload: %{},
        status: "pending",
        attempts: 2,
        next_retry_at: DateTime.add(DateTime.utc_now(), -120, :second)
      }

      delivery_repo = fn _repo -> {:ok, [delivery1, delivery2]} end

      retry_fn = fn params, _opts ->
        send(test_pid, {:retried, params.delivery.id})
        {:ok, %Delivery{}}
      end

      {:ok, pid} =
        RetryWorker.start_link(
          name: :"test_retry_worker_poll_#{:erlang.unique_integer([:positive])}",
          delivery_repo_fn: delivery_repo,
          retry_fn: retry_fn,
          poll_interval: 60_000
        )

      # Manually trigger the poll
      send(pid, :poll)

      # Wait for processing
      Process.sleep(100)

      assert_received {:retried, "del-1"}
      assert_received {:retried, "del-2"}

      GenServer.stop(pid)
    end

    test "handles empty pending retries gracefully" do
      delivery_repo = fn _repo -> {:ok, []} end
      retry_fn = fn _params, _opts -> {:ok, %Delivery{}} end

      {:ok, pid} =
        RetryWorker.start_link(
          name: :"test_retry_worker_empty_#{:erlang.unique_integer([:positive])}",
          delivery_repo_fn: delivery_repo,
          retry_fn: retry_fn,
          poll_interval: 60_000
        )

      # Should not crash
      send(pid, :poll)
      Process.sleep(50)

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
