defmodule Agents.Pipeline.Application.UseCases.GetPipelineKanbanTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Application.UseCases.GetPipelineKanban
  alias Agents.Tickets.Domain.Entities.Ticket

  defmodule PipelineParserStub do
    def parse_file(_path) do
      {:ok,
       %Agents.Pipeline.Domain.Entities.PipelineConfig{
         version: 1,
         name: "test",
         description: nil,
         deploy_targets: [],
         stages: [
           %Agents.Pipeline.Domain.Entities.Stage{
             id: "test",
             type: "verification",
             steps: [],
             gates: []
           },
           %Agents.Pipeline.Domain.Entities.Stage{
             id: "deploy",
             type: "deploy",
             steps: [],
             gates: []
           }
         ]
       }}
    end
  end

  test "groups active tickets into ordered kanban stages" do
    tickets = [
      Ticket.new(%{number: 101, title: "Ready ticket", lifecycle_stage: "ready", state: "open"}),
      Ticket.new(%{number: 102, title: "Running ticket", task_status: "running", state: "open"}),
      Ticket.new(%{
        number: 103,
        title: "Review ticket",
        lifecycle_stage: "in_review",
        state: "open"
      }),
      Ticket.new(%{
        number: 104,
        title: "CI ticket",
        lifecycle_stage: "ci_testing",
        state: "open"
      }),
      Ticket.new(%{
        number: 105,
        title: "Closed ticket",
        lifecycle_stage: "deployed",
        state: "closed"
      })
    ]

    assert {:ok, kanban} =
             GetPipelineKanban.execute(tickets, pipeline_parser: PipelineParserStub)

    assert Enum.map(kanban.stages, & &1.id) == [
             "ready",
             "in_progress",
             "in_review",
             "ci_testing",
             "deployed"
           ]

    assert stage_ticket_numbers(kanban, "ready") == [101]
    assert stage_ticket_numbers(kanban, "in_progress") == [102]
    assert stage_ticket_numbers(kanban, "in_review") == [103]
    assert stage_ticket_numbers(kanban, "ci_testing") == [104]
    assert stage_ticket_numbers(kanban, "deployed") == []
  end

  defp stage_ticket_numbers(kanban, stage_id) do
    kanban.stages
    |> Enum.find(&(&1.id == stage_id))
    |> Map.fetch!(:tickets)
    |> Enum.map(& &1.number)
  end
end
