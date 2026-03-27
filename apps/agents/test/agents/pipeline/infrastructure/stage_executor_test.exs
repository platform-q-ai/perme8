defmodule Agents.Pipeline.Infrastructure.StageExecutorTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Domain.Entities.{Stage, Step}
  alias Agents.Pipeline.Infrastructure.StageExecutor

  test "retries transient failures using configured retries" do
    marker = "/tmp/stage-executor-retry-#{System.unique_integer([:positive])}"

    stage =
      Stage.new(%{
        id: "test",
        type: "verification",
        steps: [
          Step.new(%{
            name: "retry-once",
            run:
              "if [ -f #{marker} ]; then rm #{marker}; exit 0; else touch #{marker}; exit 1; fi",
            retries: 1,
            env: %{}
          })
        ]
      })

    assert {:ok,
            %{exit_code: 0, metadata: %{"steps" => [%{"attempt" => 2, "name" => "retry-once"}]}}} =
             StageExecutor.execute(stage, %{})
  end

  test "times out long-running commands using timeout_seconds" do
    stage =
      Stage.new(%{
        id: "test",
        type: "verification",
        steps: [
          Step.new(%{
            name: "timeout",
            run: "sleep 2",
            timeout_seconds: 1,
            retries: 0,
            env: %{}
          })
        ]
      })

    assert {:error, %{reason: :timeout, output: output}} = StageExecutor.execute(stage, %{})
    assert output =~ "timed out"
  end
end
