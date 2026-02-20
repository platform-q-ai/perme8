defmodule Agents.Sessions.Infrastructure.Adapters.DockerAdapterTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.Adapters.DockerAdapter

  describe "start/2" do
    test "returns container_id and port on success" do
      mock_cmd = fn
        "docker", ["run" | _], _opts ->
          {"abc123def\n", 0}

        "docker", ["port", "abc123def", "4096"], _opts ->
          {"0.0.0.0:32768\n", 0}
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
            {"0.0.0.0:32768\n", 0}
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
  end

  describe "stop/1" do
    test "returns :ok on success" do
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

    test "returns not_found for non-existent container" do
      mock_cmd = fn "docker", ["inspect" | _], _opts ->
        {"Error: No such object\n", 1}
      end

      assert {:ok, :not_found} = DockerAdapter.status("nonexistent", system_cmd: mock_cmd)
    end
  end
end
