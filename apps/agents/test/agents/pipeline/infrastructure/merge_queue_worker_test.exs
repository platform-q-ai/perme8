defmodule Agents.Pipeline.Infrastructure.MergeQueueWorkerTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.MergeQueueWorker

  test "tracks queue order and active item" do
    name = String.to_atom("merge_queue_worker_#{System.unique_integer([:positive])}")
    start_supervised!({MergeQueueWorker, name: name})

    assert {:ok, %{status: :queued}} = MergeQueueWorker.enqueue(1, name: name)
    assert {:ok, %{status: :queued}} = MergeQueueWorker.enqueue(2, name: name)
    assert {:ok, :claimed} = MergeQueueWorker.claim_next(1, name: name)
    assert :ok = MergeQueueWorker.complete(1, name: name)

    snapshot = MergeQueueWorker.snapshot(name: name)
    assert snapshot.active == nil
    assert snapshot.queue == [2]
  end

  test "records failures and removes failed pull requests from the queue" do
    name = String.to_atom("merge_queue_worker_#{System.unique_integer([:positive])}")
    start_supervised!({MergeQueueWorker, name: name})

    assert {:ok, _} = MergeQueueWorker.enqueue(7, name: name)
    assert {:ok, :claimed} = MergeQueueWorker.claim_next(7, name: name)
    assert :ok = MergeQueueWorker.fail(7, :validation_failed, name: name)

    snapshot = MergeQueueWorker.snapshot(name: name)
    assert snapshot.active == nil
    assert snapshot.queue == []
    assert snapshot.failed[7] == :validation_failed
  end
end
