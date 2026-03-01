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
    {opts, rest, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    image_name = List.first(rest) || "opencode"

    image_config =
      case Map.get(@images, image_name) do
        nil ->
          valid = @images |> Map.keys() |> Enum.join(", ")
          Mix.shell().error([:red, "Unknown image: #{image_name}. Valid images: #{valid}"])
          exit({:shutdown, 1})

        config ->
          config
      end

    tag = Keyword.get(opts, :tag, image_config.default_tag)
    root = umbrella_root()
    context = Path.join(root, image_config.path)

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
      " from #{image_config.path}..."
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
