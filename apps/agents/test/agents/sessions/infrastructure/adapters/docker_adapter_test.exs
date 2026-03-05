defmodule Agents.Sessions.Infrastructure.Adapters.DockerAdapterTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.Adapters.DockerAdapter

  describe "start/2" do
    test "returns container_id and port on success" do
      mock_cmd = fn
        "docker", ["run" | _], _opts ->
          {"abc123def\n", 0}

        "docker", ["port", "abc123def", "4096"], _opts ->
          {"127.0.0.1:32768\n", 0}
      end

      assert {:ok, %{container_id: "abc123def", port: 32_768}} =
               DockerAdapter.start("perme8-opencode", system_cmd: mock_cmd)
    end

    test "passes env vars from config" do
      test_pid = self()

      mock_cmd = fn
        "docker", args, _opts ->
          send(test_pid, {:docker_args, args})

          if List.first(args) == "run" do
            {"container123\n", 0}
          else
            {"127.0.0.1:32768\n", 0}
          end
      end

      DockerAdapter.start("perme8-opencode",
        system_cmd: mock_cmd,
        env: %{ANTHROPIC_API_KEY: "test-key"}
      )

      assert_receive {:docker_args, args}
      assert "--env" in args
      assert "ANTHROPIC_API_KEY=test-key" in args
    end

    test "returns error when docker run fails" do
      mock_cmd = fn "docker", ["run" | _], _opts ->
        {"Error: image not found\n", 1}
      end

      assert {:error, {:docker_run_failed, 1, _}} =
               DockerAdapter.start("perme8-opencode", system_cmd: mock_cmd)
    end

    test "retries docker port when port is not yet published" do
      test_pid = self()

      mock_cmd = fn
        "docker", ["run" | _], _opts ->
          {"abc123retry\n", 0}

        "docker", ["port", "abc123retry", "4096"], _opts ->
          count = Process.get(:port_call_count, 0) + 1
          Process.put(:port_call_count, count)
          send(test_pid, {:port_attempt, count})

          if count < 3 do
            {"no public port '4096' published for abc123retry\n", 1}
          else
            {"127.0.0.1:32770\n", 0}
          end

        "docker", ["inspect", "--format", "{{.State.Running}}", "abc123retry"], _opts ->
          {"true\n", 0}
      end

      assert {:ok, %{container_id: "abc123retry", port: 32_770}} =
               DockerAdapter.start("perme8-opencode", system_cmd: mock_cmd)

      assert_receive {:port_attempt, 1}
      assert_receive {:port_attempt, 2}
      assert_receive {:port_attempt, 3}
    end

    test "returns error after exhausting port retries" do
      mock_cmd = fn
        "docker", ["run" | _], _opts ->
          {"abc123fail\n", 0}

        "docker", ["port", "abc123fail", "4096"], _opts ->
          {"no public port '4096' published for abc123fail\n", 1}

        "docker", ["inspect", "--format", "{{.State.Running}}", "abc123fail"], _opts ->
          {"true\n", 0}
      end

      assert {:error, {:docker_port_failed, 1, _}} =
               DockerAdapter.start("perme8-opencode", system_cmd: mock_cmd)
    end

    test "returns container logs when container exits before port is published" do
      mock_cmd = fn
        "docker", ["run" | _], _opts ->
          {"deadbeef123\n", 0}

        "docker", ["port", "deadbeef123", "4096"], _opts ->
          {"no public port '4096' published for deadbeef123\n", 1}

        "docker", ["inspect", "--format", "{{.State.Running}}", "deadbeef123"], _opts ->
          {"false\n", 0}

        "docker", ["logs", "--tail", "20", "deadbeef123"], _opts ->
          {"error: GITHUB_APP_PEM is required\n", 0}
      end

      assert {:error, {:container_exited, "deadbeef123", logs}} =
               DockerAdapter.start("perme8-opencode", system_cmd: mock_cmd)

      assert logs =~ "GITHUB_APP_PEM is required"
    end
  end

  describe "start/2 resource limits" do
    test "uses reduced resource limits for light images" do
      test_pid = self()

      mock_cmd = fn
        "docker", args, _opts ->
          send(test_pid, {:docker_args, args})

          if List.first(args) == "run" do
            {"light-container\n", 0}
          else
            {"127.0.0.1:32768\n", 0}
          end
      end

      DockerAdapter.start("perme8-opencode-light", system_cmd: mock_cmd, env: %{})

      assert_receive {:docker_args, args}
      assert "--memory=512m" in args
      assert "--cpus=1" in args
      refute "--memory=2g" in args
      refute "--cpus=2" in args
    end

    test "uses default resource limits for standard images" do
      test_pid = self()

      mock_cmd = fn
        "docker", args, _opts ->
          send(test_pid, {:docker_args, args})

          if List.first(args) == "run" do
            {"standard-container\n", 0}
          else
            {"127.0.0.1:32768\n", 0}
          end
      end

      DockerAdapter.start("perme8-opencode", system_cmd: mock_cmd, env: %{})

      assert_receive {:docker_args, args}
      assert "--memory=2g" in args
      assert "--cpus=2" in args
    end
  end

  describe "stop/1" do
    test "runs docker stop and returns :ok on success" do
      mock_cmd = fn "docker", ["stop", "abc123"], _opts ->
        {"abc123\n", 0}
      end

      assert :ok = DockerAdapter.stop("abc123", system_cmd: mock_cmd)
    end

    test "returns error when container not found" do
      mock_cmd = fn "docker", ["stop", "nonexistent"], _opts ->
        {"Error: No such container\n", 1}
      end

      assert {:error, {:docker_stop_failed, 1, _}} =
               DockerAdapter.stop("nonexistent", system_cmd: mock_cmd)
    end
  end

  describe "remove/1" do
    test "runs docker rm -f and returns :ok on success" do
      mock_cmd = fn "docker", ["rm", "-f", "abc123"], _opts ->
        {"abc123\n", 0}
      end

      assert :ok = DockerAdapter.remove("abc123", system_cmd: mock_cmd)
    end

    test "returns error when container not found" do
      mock_cmd = fn "docker", ["rm", "-f", "nonexistent"], _opts ->
        {"Error: No such container\n", 1}
      end

      assert {:error, {:docker_remove_failed, 1, _}} =
               DockerAdapter.remove("nonexistent", system_cmd: mock_cmd)
    end
  end

  describe "restart/1" do
    test "runs docker start and returns port on success" do
      mock_cmd = fn
        "docker", ["start", "abc123"], _opts ->
          {"abc123\n", 0}

        "docker", ["port", "abc123", "4096"], _opts ->
          {"127.0.0.1:32800\n", 0}
      end

      assert {:ok, %{port: 32_800}} = DockerAdapter.restart("abc123", system_cmd: mock_cmd)
    end

    test "returns error when container doesn't exist" do
      mock_cmd = fn "docker", ["start", "nonexistent"], _opts ->
        {"Error: No such container\n", 1}
      end

      assert {:error, {:docker_start_failed, 1, _}} =
               DockerAdapter.restart("nonexistent", system_cmd: mock_cmd)
    end

    test "retries port discovery after restart" do
      test_pid = self()

      mock_cmd = fn
        "docker", ["start", "abc123"], _opts ->
          {"abc123\n", 0}

        "docker", ["port", "abc123", "4096"], _opts ->
          count = Process.get(:restart_port_count, 0) + 1
          Process.put(:restart_port_count, count)
          send(test_pid, {:restart_port_attempt, count})

          if count < 2 do
            {"no public port '4096' published\n", 1}
          else
            {"127.0.0.1:32801\n", 0}
          end
      end

      assert {:ok, %{port: 32_801}} = DockerAdapter.restart("abc123", system_cmd: mock_cmd)
      assert_receive {:restart_port_attempt, 1}
      assert_receive {:restart_port_attempt, 2}
    end
  end

  describe "status/1" do
    test "returns running for a running container" do
      mock_cmd = fn "docker", ["inspect" | _], _opts ->
        {"running\n", 0}
      end

      assert {:ok, :running} = DockerAdapter.status("abc123", system_cmd: mock_cmd)
    end

    test "returns stopped for an exited container" do
      mock_cmd = fn "docker", ["inspect" | _], _opts ->
        {"exited\n", 0}
      end

      assert {:ok, :stopped} = DockerAdapter.status("abc123", system_cmd: mock_cmd)
    end

    test "returns error for unexpected exit codes" do
      mock_cmd = fn "docker", ["inspect" | _], _opts ->
        {"Cannot connect to Docker daemon\n", 125}
      end

      assert {:error, {:docker_inspect_failed, 125, _}} =
               DockerAdapter.status("abc123", system_cmd: mock_cmd)
    end

    test "returns not_found for non-existent container" do
      mock_cmd = fn "docker", ["inspect" | _], _opts ->
        {"Error: No such object\n", 1}
      end

      assert {:ok, :not_found} = DockerAdapter.status("nonexistent", system_cmd: mock_cmd)
    end
  end

  describe "prepare_fresh_start/2" do
    test "falls back to main branch when repo_branch is unsafe" do
      test_pid = self()

      mock_cmd = fn "docker",
                    ["exec", "-e", "GIT_TERMINAL_PROMPT=0", "abc123", "bash", "-lc", command],
                    _opts ->
        send(test_pid, {:command, command})
        {"", 0}
      end

      assert :ok =
               DockerAdapter.prepare_fresh_start("abc123",
                 system_cmd: mock_cmd,
                 repo_branch: "main; rm -rf /"
               )

      assert_receive {:command, command}
      assert String.contains?(command, "origin 'main'")
      refute String.contains?(command, "rm -rf")
    end
  end
end
