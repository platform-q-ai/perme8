defmodule Agents.Sessions.Infrastructure.Adapters.DockerAdapter do
  @moduledoc """
  Docker CLI adapter for managing opencode containers.

  Containers are task-scoped: stopped on completion (preserving state for resume),
  and only removed on explicit user delete.

  Uses `System.cmd/3` (injectable for testing) to interact with the Docker daemon.
  """

  @behaviour Agents.Sessions.Application.Behaviours.ContainerProviderBehaviour

  alias Agents.Sessions.Application.SessionsConfig

  @impl true
  def start(image, opts \\ []) do
    system_cmd = Keyword.get(opts, :system_cmd, &System.cmd/3)
    env = Keyword.get(opts, :env, SessionsConfig.container_env())

    env_args = build_env_args(env)

    args =
      [
        "run",
        "-d",
        "-p",
        "127.0.0.1:0:4096",
        "--memory=2g",
        "--cpus=2"
      ] ++
        env_args ++ [image]

    case system_cmd.("docker", args, stderr_to_stdout: true) do
      {output, 0} ->
        container_id = String.trim(output)
        discover_port(container_id, system_cmd)

      {output, exit_code} ->
        {:error, {:docker_run_failed, exit_code, String.trim(output)}}
    end
  end

  @impl true
  def stop(container_id, opts \\ []) do
    system_cmd = Keyword.get(opts, :system_cmd, &System.cmd/3)

    case system_cmd.("docker", ["stop", container_id], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, exit_code} ->
        {:error, {:docker_stop_failed, exit_code, String.trim(output)}}
    end
  end

  @impl true
  def remove(container_id, opts \\ []) do
    system_cmd = Keyword.get(opts, :system_cmd, &System.cmd/3)

    case system_cmd.("docker", ["rm", "-f", container_id], stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, exit_code} ->
        {:error, {:docker_remove_failed, exit_code, String.trim(output)}}
    end
  end

  @impl true
  def restart(container_id, opts \\ []) do
    system_cmd = Keyword.get(opts, :system_cmd, &System.cmd/3)

    case system_cmd.("docker", ["start", container_id], stderr_to_stdout: true) do
      {_output, 0} ->
        discover_port_for_restart(container_id, system_cmd)

      {output, exit_code} ->
        {:error, {:docker_start_failed, exit_code, String.trim(output)}}
    end
  end

  @impl true
  def status(container_id, opts \\ []) do
    system_cmd = Keyword.get(opts, :system_cmd, &System.cmd/3)

    case system_cmd.(
           "docker",
           ["inspect", "--format", "{{.State.Status}}", container_id],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        parse_status(String.trim(output))

      {_output, 1} ->
        {:ok, :not_found}

      {output, exit_code} ->
        {:error, {:docker_inspect_failed, exit_code, String.trim(output)}}
    end
  end

  @impl true
  def stats(container_id, opts \\ []) do
    system_cmd = Keyword.get(opts, :system_cmd, &System.cmd/3)

    format = ~S({"cpu":"{{.CPUPerc}}","mem_usage":"{{.MemUsage}}"})

    case system_cmd.(
           "docker",
           ["stats", "--no-stream", "--format", format, container_id],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        parse_stats(String.trim(output))

      {output, exit_code} ->
        {:error, {:docker_stats_failed, exit_code, String.trim(output)}}
    end
  end

  @impl true
  def prepare_fresh_start(container_id, opts \\ []) do
    system_cmd = Keyword.get(opts, :system_cmd, &System.cmd/3)

    repo_branch =
      opts
      |> Keyword.get(:repo_branch, Application.get_env(:agents, :repo_branch, "main"))
      |> safe_repo_branch()

    command = fresh_start_command(repo_branch)

    case system_cmd.("docker", ["exec", container_id, "bash", "-lc", command],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        :ok

      {output, exit_code} ->
        {:error, {:docker_prepare_fresh_start_failed, exit_code, String.trim(output)}}
    end
  end

  @safe_git_ref ~r/^[A-Za-z0-9._\/-]+$/

  defp safe_repo_branch(branch) when is_binary(branch) do
    candidate = String.trim(branch)

    if candidate != "" and Regex.match?(@safe_git_ref, candidate) do
      candidate
    else
      "main"
    end
  end

  defp safe_repo_branch(_), do: "main"

  defp fresh_start_command(repo_branch) do
    [
      "set -e",
      workspace_repo_sync_command(repo_branch),
      skills_repo_sync_command()
    ]
    |> Enum.join(" && ")
  end

  defp workspace_repo_sync_command(repo_branch) do
    "if [ -d /workspace/perme8/.git ]; then git -C /workspace/perme8 pull --ff-only origin '#{repo_branch}'; fi"
  end

  defp skills_repo_sync_command do
    "if [ -d \"$HOME/.claude/skills/.git\" ]; then git -C \"$HOME/.claude/skills\" pull --ff-only origin main || git -C \"$HOME/.claude/skills\" pull --ff-only origin master; fi"
  end

  @port_retries 5
  @port_retry_interval_ms 500

  defp discover_port(container_id, system_cmd, retries \\ @port_retries) do
    case system_cmd.("docker", ["port", container_id, "4096"], stderr_to_stdout: true) do
      {output, 0} ->
        port = parse_port(String.trim(output))
        {:ok, %{container_id: container_id, port: port}}

      {_output, _exit_code} when retries > 1 ->
        # Check if container is still running before retrying
        case container_running?(container_id, system_cmd) do
          true ->
            Process.sleep(@port_retry_interval_ms)
            discover_port(container_id, system_cmd, retries - 1)

          false ->
            # Container exited — grab logs for diagnostics
            logs = fetch_logs(container_id, system_cmd)
            {:error, {:container_exited, container_id, logs}}
        end

      {output, exit_code} ->
        {:error, {:docker_port_failed, exit_code, String.trim(output)}}
    end
  end

  defp discover_port_for_restart(container_id, system_cmd, retries \\ @port_retries) do
    case system_cmd.("docker", ["port", container_id, "4096"], stderr_to_stdout: true) do
      {output, 0} ->
        port = parse_port(String.trim(output))
        {:ok, %{port: port}}

      {_output, _exit_code} when retries > 1 ->
        Process.sleep(@port_retry_interval_ms)
        discover_port_for_restart(container_id, system_cmd, retries - 1)

      {output, exit_code} ->
        {:error, {:docker_port_failed, exit_code, String.trim(output)}}
    end
  end

  defp container_running?(container_id, system_cmd) do
    case system_cmd.(
           "docker",
           ["inspect", "--format", "{{.State.Running}}", container_id],
           stderr_to_stdout: true
         ) do
      {"true\n", 0} -> true
      _ -> false
    end
  end

  defp fetch_logs(container_id, system_cmd) do
    case system_cmd.("docker", ["logs", "--tail", "20", container_id], stderr_to_stdout: true) do
      {output, 0} -> String.trim(output)
      _ -> "unable to fetch logs"
    end
  end

  defp parse_port(output) do
    # Format: "0.0.0.0:32768" or ":::32768"
    output
    |> String.split(":")
    |> List.last()
    |> String.to_integer()
  end

  defp parse_status("running"), do: {:ok, :running}
  defp parse_status("exited"), do: {:ok, :stopped}
  defp parse_status("created"), do: {:ok, :stopped}
  defp parse_status("dead"), do: {:ok, :stopped}
  defp parse_status(_), do: {:ok, :not_found}

  defp parse_stats(json) do
    case Jason.decode(json) do
      {:ok, %{"cpu" => cpu_str, "mem_usage" => mem_str}} ->
        cpu_percent = parse_percent(cpu_str)
        {mem_usage, mem_limit} = parse_mem_usage(mem_str)
        {:ok, %{cpu_percent: cpu_percent, memory_usage: mem_usage, memory_limit: mem_limit}}

      _ ->
        {:error, :stats_parse_failed}
    end
  end

  # "0.35%" -> 0.35
  defp parse_percent(str) do
    str
    |> String.replace("%", "")
    |> String.trim()
    |> Float.parse()
    |> case do
      {val, _} -> val
      :error -> 0.0
    end
  end

  # "128.5MiB / 512MiB" -> {134_742_016, 536_870_912}
  defp parse_mem_usage(str) do
    case String.split(str, "/") do
      [usage_str, limit_str] ->
        {parse_mem_value(String.trim(usage_str)), parse_mem_value(String.trim(limit_str))}

      _ ->
        {0, 0}
    end
  end

  defp parse_mem_value(str) do
    cond do
      String.ends_with?(str, "GiB") ->
        parse_float_prefix(str) |> Kernel.*(1_073_741_824) |> round()

      String.ends_with?(str, "MiB") ->
        parse_float_prefix(str) |> Kernel.*(1_048_576) |> round()

      String.ends_with?(str, "KiB") ->
        parse_float_prefix(str) |> Kernel.*(1_024) |> round()

      String.ends_with?(str, "B") ->
        parse_float_prefix(str) |> round()

      true ->
        0
    end
  end

  defp parse_float_prefix(str) do
    str
    |> String.replace(~r/[A-Za-z]+$/, "")
    |> String.trim()
    |> Float.parse()
    |> case do
      {val, _} -> val
      :error -> 0.0
    end
  end

  defp build_env_args(env) when is_map(env) do
    env
    |> Enum.flat_map(fn {key, value} ->
      if value do
        ["--env", "#{key}=#{value}"]
      else
        []
      end
    end)
  end

  defp build_env_args(_), do: []
end
