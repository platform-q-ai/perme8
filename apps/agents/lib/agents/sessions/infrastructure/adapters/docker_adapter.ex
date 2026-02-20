defmodule Agents.Sessions.Infrastructure.Adapters.DockerAdapter do
  @moduledoc """
  Docker CLI adapter for managing ephemeral opencode containers.

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
        "--rm",
        "--cap-drop=ALL",
        "--memory=512m",
        "--cpus=1"
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
    end
  end

  defp discover_port(container_id, system_cmd) do
    case system_cmd.("docker", ["port", container_id, "4096"], stderr_to_stdout: true) do
      {output, 0} ->
        port = parse_port(String.trim(output))
        {:ok, %{container_id: container_id, port: port}}

      {output, exit_code} ->
        {:error, {:docker_port_failed, exit_code, String.trim(output)}}
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
