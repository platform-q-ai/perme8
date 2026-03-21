defmodule Agents.Pipeline.Infrastructure.GitCommandRunner do
  @moduledoc false

  @spec run([String.t()], keyword()) :: {integer(), String.t(), String.t()}
  def run([command | args], opts \\ []) do
    env = Keyword.get(opts, :env, [])
    cd = Keyword.get(opts, :cd, File.cwd!())

    case System.cmd(command, args, stderr_to_stdout: false, env: env, cd: cd) do
      {stdout, 0} -> {0, stdout, ""}
      {stdout, code} -> {code, "", stdout}
    end
  rescue
    error -> {1, "", Exception.message(error)}
  end
end
