defmodule Agents.Sessions.QueueRoutingTest do
  use Agents.DataCase

  alias Agents.Repo
  alias Agents.Sessions
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  import Agents.Test.AccountsFixtures

  defp create_task(user, attrs) do
    default_attrs = %{
      instruction: "Queue task",
      user_id: user.id,
      status: "pending",
      container_id: nil
    }

    %TaskSchema{}
    |> TaskSchema.changeset(Map.merge(default_attrs, attrs))
    |> Repo.insert!()
  end

  defp with_queue_v2_enabled(enabled, fun) do
    original = Application.get_env(:agents, :sessions, [])
    updated = Keyword.put(original, :queue_v2_enabled, enabled)
    Application.put_env(:agents, :sessions, updated)

    try do
      fun.()
    after
      Application.put_env(:agents, :sessions, original)
    end
  end

  describe "feature-flag queue routing" do
    test "get_queue_state/1 returns legacy map converted from QueueSnapshot when v2 enabled" do
      with_queue_v2_enabled(true, fn ->
        user = user_fixture()

        _queued =
          create_task(user, %{status: "queued", queue_position: 1, container_id: "container-1"})

        state = Sessions.get_queue_state(user.id)

        assert is_map(state)
        assert is_list(state.queued)
        assert is_map(List.first(state.queued))
        refute Map.has_key?(List.first(state.queued), :__struct__)
      end)
    end

    test "notify_task_terminal_status/4 publishes queue_snapshot when v2 enabled" do
      with_queue_v2_enabled(true, fn ->
        user = user_fixture()
        _running = create_task(user, %{status: "running"})

        queued =
          create_task(user, %{status: "queued", queue_position: 1, container_id: "container-1"})

        Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")

        assert :ok = Sessions.notify_task_terminal_status(user.id, queued.id, :completed)

        user_id = user.id
        assert_receive {:queue_snapshot, ^user_id, _snapshot}
        refute_receive {:queue_updated, ^user_id, _legacy_state}
      end)
    end

    test "notify_task_terminal_status/4 publishes queue_updated when v2 disabled" do
      with_queue_v2_enabled(false, fn ->
        user = user_fixture()
        _running = create_task(user, %{status: "running"})

        queued =
          create_task(user, %{status: "queued", queue_position: 1, container_id: "container-1"})

        Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")

        assert :ok = Sessions.notify_task_terminal_status(user.id, queued.id, :completed)

        user_id = user.id
        assert_receive {:queue_updated, ^user_id, _legacy_state}
      end)
    end
  end
end
