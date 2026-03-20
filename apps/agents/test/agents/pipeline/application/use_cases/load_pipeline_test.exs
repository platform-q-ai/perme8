defmodule Agents.Pipeline.TestDoubles.ParserStub do
  def parse_file(path), do: Process.get({__MODULE__, :parse_file}).(path)
end

defmodule Agents.Pipeline.Application.UseCases.LoadPipelineTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.TestDoubles.ParserStub

  describe "execute/1" do
    test "loads and validates pipeline config from file" do
      yaml = """
      version: 1
      pipeline:
        name: perme8-core
        deploy_targets:
          - id: dev
            environment: development
            provider: docker
        stages:
          - id: warm-pool
            type: warm_pool
            deploy_target: dev
            steps:
              - name: prestart
                run: scripts/warm_pool.sh
      """

      path = write_tmp_file(yaml)

      assert {:ok, config} = LoadPipeline.execute(path)
      assert config.name == "perme8-core"
      assert length(config.stages) == 1
    end

    test "returns validation errors for invalid file content" do
      yaml = """
      version: 1
      pipeline:
        name: broken
      """

      path = write_tmp_file(yaml)

      assert {:error, errors} = LoadPipeline.execute(path)
      assert "pipeline.deploy_targets must be a non-empty list" in errors
      assert "pipeline.stages must be a non-empty list" in errors
    end

    test "supports parser injection for alternate loaders" do
      Process.put({ParserStub, :parse_file}, fn path -> {:ok, %{path: path}} end)

      assert {:ok, %{path: "custom.yml"}} =
               LoadPipeline.execute("custom.yml", parser: ParserStub)
    end
  end

  defp write_tmp_file(content) do
    path = Path.join(System.tmp_dir!(), "pipeline-#{System.unique_integer([:positive])}.yml")
    File.write!(path, content)
    path
  end
end
