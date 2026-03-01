defmodule Mix.Tasks.Docker.Build do
  @shortdoc "Builds a perme8 Docker image (opencode or pi)"

  @moduledoc """
  Builds a Docker image used by coding sessions.

  Runs `docker build` against the specified image's Dockerfile directory
  and tags the resulting image accordingly.

  ## Usage

      mix docker.build [image] [options]

  ## Arguments

    * `image` - Which image to build: `opencode` (default) or `pi`

  ## Options

    * `--tag` / `-t` - Image tag (default: `perme8-<image>`)
    * `--no-cache` - Build without Docker layer cache

  ## Examples

      mix docker.build
      mix docker.build opencode
      mix docker.build pi
      mix docker.build pi --tag perme8-pi:latest
      mix docker.build --no-cache

  ## Exit codes

  - 0: Image built successfully
  - 1: Build failed
  """

  use Mix.Task
  use Boundary, top_level?: true

  @images %{
    "opencode" => %{path: "infra/opencode", default_tag: "perme8-opencode"},
    "pi" => %{path: "infra/pi", default_tag: "perme8-pi"}
  }

  @switches [tag: :string, no_cache: :boolean]
  @aliases [t: :tag]

  @impl Mix.Task
  def run(args) do
    case resolve_config(args) do
      {:ok, config} ->
        root = umbrella_root()
        context = Path.join(root, config.image_path)

        unless File.dir?(context) do
          Mix.shell().error([:red, "Dockerfile directory not found: #{context}"])
          exit({:shutdown, 1})
        end

        cmd_args = build_docker_args(config.tag, config.no_cache, context)

        Mix.shell().info([
          :cyan,
          "Building Docker image ",
          :bright,
          config.tag,
          :reset,
          :cyan,
          " from #{config.image_path}..."
        ])

        case System.cmd("docker", cmd_args, cd: root, into: IO.stream(:stdio, :line)) do
          {_, 0} ->
            Mix.shell().info([:green, "Image #{config.tag} built successfully"])

          {_, code} ->
            Mix.shell().error([:red, "docker build failed (exit code #{code})"])
            exit({:shutdown, 1})
        end

      {:error, message} ->
        Mix.shell().error([:red, message])
        exit({:shutdown, 1})
    end
  end

  @doc false
  def resolve_config(args) do
    {opts, rest, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    image_name = List.first(rest) || "opencode"

    case Map.get(@images, image_name) do
      nil ->
        valid = @images |> Map.keys() |> Enum.join(", ")
        {:error, "Unknown image: #{image_name}. Valid images: #{valid}"}

      image_config ->
        {:ok,
         %{
           image_name: image_name,
           image_path: image_config.path,
           tag: Keyword.get(opts, :tag, image_config.default_tag),
           no_cache: Keyword.get(opts, :no_cache, false)
         }}
    end
  end

  @doc false
  def build_docker_args(tag, no_cache, context) do
    cache_flag = if no_cache, do: ["--no-cache"], else: []
    ["build", "-t", tag] ++ cache_flag ++ [context]
  end

  defp umbrella_root do
    case Mix.Project.config()[:build_path] do
      nil -> File.cwd!()
      build_path -> build_path |> Path.expand() |> Path.dirname()
    end
  end
end
