defmodule Agents.Pipeline.Application.UseCases.ProjectTicketLifecycleFromRunTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Application.PipelineConfigBuilder
  alias Agents.Pipeline.Application.UseCases.ProjectTicketLifecycleFromRun
  alias Agents.Pipeline.Domain.Entities.PipelineRun

  defmodule TicketRepoStub do
    def get_by_number(number), do: Process.get({__MODULE__, :get_by_number}).(number)

    def set_lifecycle_projection(number, attrs),
      do: Process.get({__MODULE__, :set_lifecycle_projection}).(number, attrs)
  end

  defmodule PipelineConfigRepoStub do
    def get_current, do: {:ok, Process.get({__MODULE__, :config})}
  end

  defmodule RecordStageTransitionStub do
    def execute(ticket_id, to_stage, opts),
      do: Process.get({__MODULE__, :execute}).(ticket_id, to_stage, opts)
  end

  setup do
    {:ok, config} =
      PipelineConfigBuilder.build(%{
        "version" => 1,
        "pipeline" => %{
          "name" => "perme8-core",
          "stages" => [
            %{
              "id" => "develop",
              "type" => "automation",
              "triggers" => ["on_ticket_play"],
              "ticket_stage" => "in_progress",
              "steps" => [%{"name" => "develop", "run" => "scripts/dev.sh", "depends_on" => []}]
            },
            %{
              "id" => "verify",
              "type" => "verification",
              "ticket_stage" => "ci_testing",
              "transitions" => [
                %{
                  "on" => "failed",
                  "to_stage" => "develop",
                  "ticket_stage_override" => "in_progress",
                  "ticket_reason" => "local checks failed"
                }
              ],
              "steps" => [%{"name" => "test", "run" => "mix test", "depends_on" => []}]
            }
          ]
        }
      })

    Process.put({PipelineConfigRepoStub, :config}, config)

    Process.put({TicketRepoStub, :get_by_number}, fn 123 ->
      {:ok, %{number: 123, lifecycle_stage: "ready"}}
    end)

    Process.put({TicketRepoStub, :set_lifecycle_projection}, fn _number, _attrs -> {:ok, %{}} end)

    Process.put({RecordStageTransitionStub, :execute}, fn _ticket_id, _to_stage, _opts ->
      {:ok, %{}}
    end)

    :ok
  end

  test "projects a running stage to the stage ticket lifecycle" do
    run =
      PipelineRun.new(%{
        id: Ecto.UUID.generate(),
        pull_request_number: 123,
        status: "running_stage"
      })

    Process.put({RecordStageTransitionStub, :execute}, fn 123, "in_progress", _opts ->
      send(self(), :transition_recorded)
      {:ok, %{}}
    end)

    assert :ok =
             ProjectTicketLifecycleFromRun.execute(run, "develop",
               ticket_repo: TicketRepoStub,
               pipeline_config_repo: PipelineConfigRepoStub,
               record_stage_transition: RecordStageTransitionStub
             )

    assert_received :transition_recorded
  end

  test "uses transition override on failure" do
    run =
      PipelineRun.new(%{
        id: Ecto.UUID.generate(),
        pull_request_number: 123,
        status: "failed",
        failure_reason: "boom"
      })

    Process.put({RecordStageTransitionStub, :execute}, fn 123, "in_progress", opts ->
      assert opts[:trigger] == "pipeline:local checks failed"
      send(self(), :failed_transition_recorded)
      {:ok, %{}}
    end)

    assert :ok =
             ProjectTicketLifecycleFromRun.execute(run, "verify",
               ticket_repo: TicketRepoStub,
               pipeline_config_repo: PipelineConfigRepoStub,
               record_stage_transition: RecordStageTransitionStub
             )

    assert_received :failed_transition_recorded
  end
end
