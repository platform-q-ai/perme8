defmodule Notifications.Infrastructure.Subscribers.TaskCompletionSubscriberTest do
  use Notifications.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Notifications.Infrastructure.Repositories.NotificationRepository
  alias Notifications.Infrastructure.Subscribers.TaskCompletionSubscriber

  import Notifications.Test.Fixtures.AccountsFixtures

  defmodule FakeTaskCompleted do
    defstruct [:event_type, :task_id, :target_user_id, :instruction]
  end

  defmodule FakeTaskFailed do
    defstruct [:event_type, :task_id, :target_user_id, :instruction, :error]
  end

  defmodule FakeTaskCancelled do
    defstruct [:event_type, :task_id, :target_user_id, :instruction]
  end

  describe "subscriptions/0" do
    test "returns the task events topic" do
      assert TaskCompletionSubscriber.subscriptions() == ["events:sessions:task"]
    end
  end

  describe "handle_event/1" do
    test "creates notification when task completes" do
      {:ok, pid} = TaskCompletionSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)

      user = user_fixture()
      task_id = Ecto.UUID.generate()

      send(pid, %FakeTaskCompleted{
        event_type: "sessions.task_completed",
        task_id: task_id,
        target_user_id: user.id,
        instruction: "Implement browser notifications"
      })

      :sys.get_state(pid)

      [notification] = NotificationRepository.list_by_user(user.id)
      assert notification.type == "task_completed"
      assert notification.title == "Task completed"
      assert notification.data["task_id"] == task_id
      assert notification.data["instruction"] == "Implement browser notifications"
    end

    test "creates notification when task fails with error context" do
      {:ok, pid} = TaskCompletionSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)

      user = user_fixture()

      send(pid, %FakeTaskFailed{
        event_type: "sessions.task_failed",
        task_id: Ecto.UUID.generate(),
        target_user_id: user.id,
        instruction: "Run migration",
        error: "Permission denied"
      })

      :sys.get_state(pid)

      [notification] = NotificationRepository.list_by_user(user.id)
      assert notification.type == "task_failed"
      assert notification.title == "Task failed"
      assert notification.data["error"] == "Permission denied"
      assert notification.body =~ "Permission denied"
    end

    test "creates notification when task is cancelled" do
      {:ok, pid} = TaskCompletionSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)

      user = user_fixture()

      send(pid, %FakeTaskCancelled{
        event_type: "sessions.task_cancelled",
        task_id: Ecto.UUID.generate(),
        target_user_id: user.id,
        instruction: "Cancel queued task"
      })

      :sys.get_state(pid)

      [notification] = NotificationRepository.list_by_user(user.id)
      assert notification.type == "task_cancelled"
      assert notification.title == "Task cancelled"
    end

    test "ignores unrelated events" do
      {:ok, pid} = TaskCompletionSubscriber.start_link([])
      Sandbox.allow(Notifications.Repo, self(), pid)

      user = user_fixture()

      send(pid, %FakeTaskCompleted{
        event_type: "sessions.task_created",
        task_id: Ecto.UUID.generate(),
        target_user_id: user.id,
        instruction: "Create task"
      })

      :sys.get_state(pid)

      assert NotificationRepository.list_by_user(user.id) == []
    end
  end
end
