defmodule Agents.Pipeline.TestDoubles.ParserStub do
  def parse_file(path), do: Process.get({__MODULE__, :parse_file}).(path)

  def parse_string(yaml),
    do: Process.get({__MODULE__, :parse_string}, fn value -> {:ok, %{yaml: value}} end).(yaml)
end

defmodule Agents.Pipeline.Application.UseCases.LoadPipelineTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.TestDoubles.ParserStub

  defmodule PipelineConfigRepoStub do
    def get_current do
      case Process.get({__MODULE__, :current}) do
        nil -> {:error, :not_found}
        current -> {:ok, current}
      end
    end

    def upsert_current(attrs) do
      current = %{yaml: Map.get(attrs, :yaml) || Map.get(attrs, "yaml")}
      Process.put({__MODULE__, :current}, current)
      {:ok, current}
    end
  end

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
            schedule:
              cron: "*/5 * * * *"
            warm_pool:
              target_count: 2
              image: ghcr.io/platform-q-ai/perme8-runtime:latest
              readiness:
                strategy: command_success
            steps:
              - name: prestart
                run: scripts/warm_pool.sh
      """

      path = write_tmp_file(yaml)

      assert {:ok, config} = LoadPipeline.execute(path)
      assert config.name == "perme8-core"
      assert length(config.stages) == 1
      assert hd(config.stages).schedule == %{"cron" => "*/5 * * * *"}
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

    test "loads the default pipeline from Agents.Repo" do
      Process.put({PipelineConfigRepoStub, :current}, %{yaml: "version: 1\n"})
      Process.put({ParserStub, :parse_string}, fn yaml -> {:ok, %{source: :repo, yaml: yaml}} end)

      assert {:ok, %{source: :repo, yaml: "version: 1\n"}} =
               LoadPipeline.execute(nil,
                 parser: ParserStub,
                 pipeline_config_repo: PipelineConfigRepoStub
               )
    end

    test "bootstraps the default pipeline document when the database is empty" do
      yaml = "version: 1\n"

      Process.delete({PipelineConfigRepoStub, :current})

      Process.put({ParserStub, :parse_string}, fn value ->
        {:ok, %{source: :bootstrapped, yaml: value}}
      end)

      assert {:ok, %{source: :bootstrapped, yaml: ^yaml}} =
               LoadPipeline.execute(nil,
                 parser: ParserStub,
                 pipeline_config_repo: PipelineConfigRepoStub,
                 bootstrap_yaml: yaml
               )

      assert {:ok, %{yaml: ^yaml}} = PipelineConfigRepoStub.get_current()
    end
  end

  defp write_tmp_file(content) do
    path = Path.join(System.tmp_dir!(), "pipeline-#{System.unique_integer([:positive])}.yml")
    File.write!(path, content)
    path
  end
end
