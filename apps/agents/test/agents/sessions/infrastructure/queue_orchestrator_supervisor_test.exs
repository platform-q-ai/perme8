defmodule Agents.Sessions.Infrastructure.QueueOrchestratorSupervisorTest do
  use Agents.DataCase

  alias Agents.Sessions.Infrastructure.QueueOrchestratorSupervisor

  import Agents.Test.AccountsFixtures

  # QueueRegistry and QueueOrchestratorSupervisor are started by the OTP app supervision tree.

  describe "ensure_started/2" do
    test "starts an orchestrator for a user" do
      user = user_fixture()

      assert {:ok, pid} = QueueOrchestratorSupervisor.ensure_started(user.id)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "returns existing pid when orchestrator already running" do
      user = user_fixture()

      assert {:ok, pid1} = QueueOrchestratorSupervisor.ensure_started(user.id)
      assert {:ok, pid2} = QueueOrchestratorSupervisor.ensure_started(user.id)
      assert pid1 == pid2
    end

    test "starts separate orchestrators for different users" do
      user1 = user_fixture()
      user2 = user_fixture()

      assert {:ok, pid1} = QueueOrchestratorSupervisor.ensure_started(user1.id)
      assert {:ok, pid2} = QueueOrchestratorSupervisor.ensure_started(user2.id)

      refute pid1 == pid2
      assert Process.alive?(pid1)
      assert Process.alive?(pid2)
    end
  end
end
