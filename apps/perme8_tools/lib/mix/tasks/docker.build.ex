defmodule Mix.Tasks.Docker.Build do
  @shortdoc "Builds the perme8-opencode Docker image"

  @moduledoc """
  Builds the Docker image used by coding sessions.

  Runs `docker build` against `infra/opencode/Dockerfile` and tags the
  resulting image as `perme8-opencode` (or a custom tag via `--tag`).

  ## Usage

      mix docker.build [options]

  ## Options

    * `--tag` / `-t` - Image tag (default: `perme8-opencode`)
    * `--no-cache` - Build without Docker layer cache

  ## Examples

      mix docker.build
      mix docker.build --tag perme8-opencode:latest
      mix docker.build --no-cache

  ## Exit codes

  - 0: Image built successfully
  - 1: Build failed
  """

  use Mix.Task
  use Boundary, top_level?: true

  @default_tag "perme8-opencode"
  @dockerfile_path "infra/opencode"
  @switches [tag: :string, no_cache: :boolean]
  @aliases [t: :tag]

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    tag = Keyword.get(opts, :tag, @default_tag)
    root = umbrella_root()
    context = Path.join(root, @dockerfile_path)

    unless File.dir?(context) do
      Mix.shell().error([:red, "Dockerfile directory not found: #{context}"])
      exit({:shutdown, 1})
    end

    cache_flag = if Keyword.get(opts, :no_cache, false), do: ["--no-cache"], else: []
    cmd_args = ["build", "-t", tag] ++ cache_flag ++ [context]

    Mix.shell().info([
      :cyan,
      "Building Docker image ",
      :bright,
      tag,
      :reset,
      :cyan,
      " from #{@dockerfile_path}..."
    ])

    case System.cmd("docker", cmd_args, cd: root, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info([:green, "Image #{tag} built successfully"])

      {_, code} ->
        Mix.shell().error([:red, "docker build failed (exit code #{code})"])
        exit({:shutdown, 1})
    end
  end

  defp umbrella_root do
    case Mix.Project.config()[:build_path] do
      nil -> File.cwd!()
      build_path -> build_path |> Path.expand() |> Path.dirname()
    end
  end
end
