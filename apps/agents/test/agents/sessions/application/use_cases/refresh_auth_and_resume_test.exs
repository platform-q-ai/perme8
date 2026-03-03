defmodule Agents.Sessions.Application.UseCases.RefreshAuthAndResumeTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Sessions.Application.UseCases.RefreshAuthAndResume

  setup :set_mox_global
  setup :verify_on_exit!

  alias Agents.Test.AccountsFixtures
  alias Agents.SessionsFixtures

  defmodule FakeAuthRefresher do
    def refresh_auth(_base_url, _client, _opts \\ []) do
      {:ok, ["anthropic"]}
    end
  end

  defmodule FailingAuthRefresher do
    def refresh_auth(_base_url, _client, _opts \\ []) do
      {:error, :auth_failed}
    end
  end

  defmodule DetailedFailAuthRefresher do
    def refresh_auth(_base_url, _client, _opts \\ []) do
      {:error,
       {:auth_refresh_failed,
        [
          %{
            provider: "openai",
            reason: {:http_error, 400, %{"error" => "invalid_grant"}}
          }
        ]}}
    end
  end

  setup do
    user = AccountsFixtures.user_fixture()

    task =
      SessionsFixtures.task_fixture(%{
        user_id: user.id,
        status: "failed",
        container_id: "container-123",
        session_id: "sess-1",
        error: "Token refresh failed: 400"
      })

    # Default stub: return the failed task for its owner
    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task_for_user, fn task_id, uid ->
      if task_id == task.id and uid == user.id, do: task, else: nil
    end)
    |> stub(:update_task_status, fn _task, _attrs -> {:ok, task} end)

    {:ok, task: task, user: user}
  end

  describe "execute/3 happy path" do
    test "restarts container, refreshes auth, and resumes", %{task: task, user: user} do
      resumed_task = %{id: "new-task-id", instruction: task.instruction}

      Agents.Mocks.ContainerProviderMock
      |> expect(:restart, fn "container-123" -> {:ok, %{port: 5000}} end)

      Agents.Mocks.OpencodeClientMock
      |> expect(:health, fn "http://localhost:5000" -> :ok end)

      resume_fn = fn _task_id, attrs, _opts ->
        assert attrs.instruction == task.instruction
        assert attrs.user_id == user.id
        {:ok, resumed_task}
      end

      assert {:ok, ^resumed_task} =
               RefreshAuthAndResume.execute(task.id, user.id,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 container_provider: Agents.Mocks.ContainerProviderMock,
                 opencode_client: Agents.Mocks.OpencodeClientMock,
                 auth_refresher: FakeAuthRefresher,
                 resume_fn: resume_fn
               )
    end
  end

  describe "execute/3 error paths" do
    test "returns :not_found when task doesn't exist", %{user: user} do
      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn "nonexistent", _ -> nil end)

      assert {:error, :not_found} =
               RefreshAuthAndResume.execute("nonexistent", user.id,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 resume_fn: fn _, _, _ -> {:ok, %{}} end
               )
    end

    test "returns :not_resumable when task is not failed", %{user: user} do
      running_task =
        SessionsFixtures.task_fixture(%{
          user_id: user.id,
          status: "running",
          container_id: "container-456"
        })

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn _, _ -> running_task end)

      assert {:error, :not_resumable} =
               RefreshAuthAndResume.execute(running_task.id, user.id,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 resume_fn: fn _, _, _ -> {:ok, %{}} end
               )
    end

    test "returns :no_container when container_id is nil", %{user: user} do
      no_container_task =
        SessionsFixtures.task_fixture(%{
          user_id: user.id,
          status: "failed",
          container_id: nil,
          error: "Container start failed"
        })

      Agents.Mocks.TaskRepositoryMock
      |> expect(:get_task_for_user, fn _, _ -> no_container_task end)

      assert {:error, :no_container} =
               RefreshAuthAndResume.execute(no_container_task.id, user.id,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 resume_fn: fn _, _, _ -> {:ok, %{}} end
               )
    end

    test "returns error when container restart fails", %{task: task, user: user} do
      Agents.Mocks.ContainerProviderMock
      |> expect(:restart, fn "container-123" -> {:error, :container_not_found} end)

      assert {:error, :container_not_found} =
               RefreshAuthAndResume.execute(task.id, user.id,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 container_provider: Agents.Mocks.ContainerProviderMock,
                 resume_fn: fn _, _, _ -> {:ok, %{}} end
               )
    end

    test "returns error when auth refresh fails", %{task: task, user: user} do
      Agents.Mocks.ContainerProviderMock
      |> expect(:restart, fn "container-123" -> {:ok, %{port: 5000}} end)

      Agents.Mocks.OpencodeClientMock
      |> expect(:health, fn "http://localhost:5000" -> :ok end)

      assert {:error, :auth_failed} =
               RefreshAuthAndResume.execute(task.id, user.id,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 container_provider: Agents.Mocks.ContainerProviderMock,
                 opencode_client: Agents.Mocks.OpencodeClientMock,
                 auth_refresher: FailingAuthRefresher,
                 resume_fn: fn _, _, _ -> {:ok, %{}} end
               )
    end

    test "persists detailed auth refresh error from provider failure", %{task: task, user: user} do
      Agents.Mocks.ContainerProviderMock
      |> expect(:restart, fn "container-123" -> {:ok, %{port: 5000}} end)

      Agents.Mocks.OpencodeClientMock
      |> expect(:health, fn "http://localhost:5000" -> :ok end)

      Agents.Mocks.TaskRepositoryMock
      |> expect(:update_task_status, fn _task, attrs ->
        assert attrs.status == "failed"
        assert attrs.error =~ "Auth refresh failed"
        assert attrs.error =~ "openai"
        assert attrs.error =~ "HTTP 400"
        assert attrs.error =~ "invalid_grant"
        {:ok, task}
      end)

      assert {:error, {:auth_refresh_failed, _failures}} =
               RefreshAuthAndResume.execute(task.id, user.id,
                 task_repo: Agents.Mocks.TaskRepositoryMock,
                 container_provider: Agents.Mocks.ContainerProviderMock,
                 opencode_client: Agents.Mocks.OpencodeClientMock,
                 auth_refresher: DetailedFailAuthRefresher,
                 resume_fn: fn _, _, _ -> {:ok, %{}} end
               )
    end
  end
end
