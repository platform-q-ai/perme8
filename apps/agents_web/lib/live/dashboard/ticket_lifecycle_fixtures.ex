defmodule AgentsWeb.DashboardLive.TicketLifecycleFixtures do
  @moduledoc """
  Dev/test fixture data for ticket lifecycle UI previews.

  Provides canned ticket datasets keyed by fixture name so that LiveView
  can be loaded with `?fixture=ticket_lifecycle_*` query params for visual
  testing without requiring real GitHub data.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Entities.TicketLifecycleEvent
  alias AgentsWeb.DashboardLive.PipelineKanbanState

  def maybe_apply_ticket_lifecycle_fixture(socket, %{"fixture" => fixture})
      when is_binary(fixture) do
    case fixture_payload(fixture) do
      payload = %{tickets: []} ->
        socket
        |> assign(:fixture, fixture)
        |> assign(
          :pipeline_editor_draft,
          Map.get(
            payload,
            :pipeline_editor_draft,
            socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
          )
        )
        |> assign(:pipeline_editor_errors, Map.get(payload, :pipeline_editor_errors, []))
        |> assign(:pipeline_editor_saved_at, Map.get(payload, :pipeline_editor_saved_at, nil))
        |> assign(
          :pipeline_editor_load_failed?,
          Map.get(
            payload,
            :pipeline_editor_load_failed?,
            socket.assigns[:pipeline_editor_load_failed?]
          )
        )
        |> assign(
          :pipeline_editor_authorized?,
          Map.get(
            payload,
            :pipeline_editor_authorized?,
            socket.assigns[:pipeline_editor_authorized?]
          )
        )

      payload ->
        active_ticket_number =
          payload[:active_ticket_number] ||
            payload.tickets |> List.first() |> then(&(&1 && &1.number))

        socket =
          socket
          |> assign(:fixture, fixture)
          |> assign(:sessions, Map.get(payload, :sessions, []))
          |> assign(:tasks_snapshot, Map.get(payload, :tasks_snapshot, []))
          |> assign(:tickets, payload.tickets)
          |> assign(
            :pipeline_editor_draft,
            Map.get(
              payload,
              :pipeline_editor_draft,
              socket.assigns[:pipeline_editor_draft] || %{"stages" => []}
            )
          )
          |> assign(:pipeline_editor_errors, Map.get(payload, :pipeline_editor_errors, []))
          |> assign(:pipeline_editor_saved_at, Map.get(payload, :pipeline_editor_saved_at, nil))
          |> assign(
            :pipeline_editor_load_failed?,
            Map.get(
              payload,
              :pipeline_editor_load_failed?,
              socket.assigns[:pipeline_editor_load_failed?]
            )
          )
          |> assign(
            :pipeline_editor_authorized?,
            Map.get(
              payload,
              :pipeline_editor_authorized?,
              socket.assigns[:pipeline_editor_authorized?]
            )
          )
          |> assign(:active_ticket_number, active_ticket_number)
          |> assign(
            :pipeline_kanban_collapsed,
            Map.get(payload, :pipeline_kanban_collapsed, false)
          )

        socket
        |> assign_fixture_pipeline_kanban(payload)
        |> maybe_schedule_pipeline_fixture_event(fixture)
    end
  end

  def maybe_apply_ticket_lifecycle_fixture(socket, _params) do
    socket
    |> assign(:fixture, nil)
    |> assign(:pipeline_kanban_collapsed, false)
    |> PipelineKanbanState.assign_pipeline_kanban()
  end

  defp maybe_schedule_pipeline_fixture_event(socket, "pipeline_kanban_live_stage_change") do
    Process.send_after(
      self(),
      %{
        event_type: "pipeline.pipeline_stage_changed",
        stage_id: "test",
        task_id: "task-425",
        session_id: nil,
        occurred_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      500
    )

    socket
  end

  defp maybe_schedule_pipeline_fixture_event(socket, _fixture), do: socket

  defp assign_fixture_pipeline_kanban(socket, %{pipeline_kanban: kanban}),
    do: assign(socket, :pipeline_kanban, kanban)

  defp assign_fixture_pipeline_kanban(socket, _payload),
    do: PipelineKanbanState.assign_pipeline_kanban(socket)

  defp fixture_payload(fixture) do
    %{tickets: ticket_lifecycle_fixture_tickets(fixture)}
    |> Map.merge(pipeline_kanban_fixture_payload(fixture))
    |> Map.merge(pipeline_editor_fixture_payload(fixture))
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_in_progress") do
    [
      lifecycle_fixture_ticket(402, "Lifecycle in progress",
        external_id: "in-progress-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -1800, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_in_progress_duration") do
    [
      lifecycle_fixture_ticket(402, "Lifecycle in progress duration",
        external_id: "in-progress-duration-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_all_stages") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      {5001, "open"},
      {5002, "ready"},
      {5003, "in_progress"},
      {5004, "in_review"},
      {5005, "ci_testing"},
      {5006, "deployed"},
      {5007, "closed"}
    ]
    |> Enum.with_index()
    |> Enum.map(fn {{number, stage}, idx} ->
      lifecycle_fixture_ticket(number, "Lifecycle stage #{stage}",
        lifecycle_stage: stage,
        lifecycle_stage_entered_at: DateTime.add(now, -3600 * (idx + 1), :second)
      )
    end)
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_timeline") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    events = [
      TicketLifecycleEvent.new(%{
        id: 1,
        ticket_id: 430,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: DateTime.add(now, -18_000, :second),
        trigger: "sync"
      }),
      TicketLifecycleEvent.new(%{
        id: 2,
        ticket_id: 430,
        from_stage: "open",
        to_stage: "ready",
        transitioned_at: DateTime.add(now, -12_000, :second),
        trigger: "manual"
      }),
      TicketLifecycleEvent.new(%{
        id: 3,
        ticket_id: 430,
        from_stage: "ready",
        to_stage: "in_progress",
        transitioned_at: DateTime.add(now, -6_000, :second),
        trigger: "manual"
      })
    ]

    [
      lifecycle_fixture_ticket(430, "Timeline fixture",
        external_id: "timeline-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(now, -6_000, :second),
        lifecycle_events: events
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_relative_durations") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    events = [
      TicketLifecycleEvent.new(%{
        id: 11,
        ticket_id: 431,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: DateTime.add(now, -10_000, :second),
        trigger: "sync"
      }),
      TicketLifecycleEvent.new(%{
        id: 12,
        ticket_id: 431,
        from_stage: "open",
        to_stage: "ready",
        transitioned_at: DateTime.add(now, -9_000, :second),
        trigger: "manual"
      }),
      TicketLifecycleEvent.new(%{
        id: 13,
        ticket_id: 431,
        from_stage: "ready",
        to_stage: "in_progress",
        transitioned_at: DateTime.add(now, -6_000, :second),
        trigger: "manual"
      })
    ]

    [
      lifecycle_fixture_ticket(431, "Relative durations fixture",
        external_id: "relative-durations-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(now, -6_000, :second),
        lifecycle_events: events
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_realtime_transition") do
    [
      lifecycle_fixture_ticket(402, "Realtime transition ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_newly_synced") do
    [
      lifecycle_fixture_ticket(450, "Newly synced ticket",
        external_id: "newly-synced-ticket",
        lifecycle_stage: "open",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -300, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_closed") do
    [
      lifecycle_fixture_ticket(451, "Closed ticket fixture",
        external_id: "closed-ticket",
        lifecycle_stage: "closed",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_no_events") do
    [
      lifecycle_fixture_ticket(452, "No events ticket fixture",
        external_id: "default-lifecycle-ticket",
        lifecycle_stage: "open",
        lifecycle_stage_entered_at: nil,
        lifecycle_events: []
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_layout_enabled") do
    pipeline_kanban_fixture_tickets()
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_stage_columns") do
    pipeline_kanban_fixture_tickets()
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_ticket_positions") do
    pipeline_kanban_fixture_tickets()
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_rollup") do
    pipeline_kanban_fixture_tickets(:rollup)
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_collapsible") do
    pipeline_kanban_fixture_tickets()
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_ticket_to_session_selection") do
    [
      lifecycle_fixture_ticket(402, "Add pipeline kanban row",
        lifecycle_stage: "in_progress",
        associated_container_id: "c-pipeline-402"
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_live_stage_change") do
    [
      lifecycle_fixture_ticket(425, "Live pipeline movement",
        lifecycle_stage: "ready",
        associated_task_id: "task-425"
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_header_status_summary") do
    [
      lifecycle_fixture_ticket(431, "Review check one", lifecycle_stage: "in_review"),
      lifecycle_fixture_ticket(432, "Review check two", lifecycle_stage: "in_review")
    ]
  end

  def ticket_lifecycle_fixture_tickets("pipeline_kanban_merge_queue") do
    [
      lifecycle_fixture_ticket(610, "Queued for merge", lifecycle_stage: "merge_queue"),
      lifecycle_fixture_ticket(611, "Still validating in CI", lifecycle_stage: "ci_testing")
    ]
  end

  def ticket_lifecycle_fixture_tickets(_fixture), do: []

  defp pipeline_kanban_fixture_payload("pipeline_kanban_collapsible"),
    do: %{pipeline_kanban_collapsed: true}

  defp pipeline_kanban_fixture_payload("pipeline_kanban_ticket_to_session_selection") do
    %{
      sessions: [
        %{
          container_id: "c-pipeline-402",
          latest_task_id: "task-402",
          latest_status: "running",
          latest_at: DateTime.utc_now() |> DateTime.truncate(:second),
          title: "Selected session: #402"
        }
      ],
      tasks_snapshot: [
        %{
          id: "task-402",
          session_id: "sdk-session-402",
          container_id: "c-pipeline-402",
          status: "running",
          instruction: "Selected session: #402",
          image: "perme8-opencode"
        }
      ]
    }
  end

  defp pipeline_kanban_fixture_payload("pipeline_kanban_merge_queue") do
    %{
      pipeline_kanban: %{
        generated_at: DateTime.utc_now() |> DateTime.truncate(:second),
        stages: [
          %{id: "ready", label: "Ready", count: 0, aggregate_status: "idle", tickets: []},
          %{
            id: "in_progress",
            label: "In Progress",
            count: 0,
            aggregate_status: "idle",
            tickets: []
          },
          %{
            id: "in_review",
            label: "In Review",
            count: 0,
            aggregate_status: "idle",
            tickets: []
          },
          %{
            id: "ci_testing",
            label: "CI Testing",
            count: 1,
            aggregate_status: "running",
            tickets: [
              %{number: 611, title: "Still validating in CI", status: "running", labels: []}
            ]
          },
          %{
            id: "merge_queue",
            label: "Merge Queue",
            count: 1,
            aggregate_status: "queued",
            tickets: [%{number: 610, title: "Queued for merge", status: "queued", labels: []}]
          },
          %{id: "deployed", label: "Deployed", count: 0, aggregate_status: "idle", tickets: []}
        ]
      }
    }
  end

  defp pipeline_kanban_fixture_payload(_fixture), do: %{}

  defp pipeline_editor_fixture_payload("pipeline_configuration_editor_loaded") do
    %{pipeline_editor_authorized?: true, pipeline_editor_draft: pipeline_editor_base_draft()}
  end

  defp pipeline_editor_fixture_payload("pipeline_configuration_editor_step_editing") do
    %{pipeline_editor_authorized?: true, pipeline_editor_draft: pipeline_editor_base_draft()}
  end

  defp pipeline_editor_fixture_payload("pipeline_configuration_editor_warm_pool_editing") do
    %{pipeline_editor_authorized?: true, pipeline_editor_draft: pipeline_editor_base_draft()}
  end

  defp pipeline_editor_fixture_payload("pipeline_configuration_editor_structure_editing") do
    %{pipeline_editor_authorized?: true, pipeline_editor_draft: pipeline_editor_structure_draft()}
  end

  defp pipeline_editor_fixture_payload("pipeline_configuration_editor_invalid_changes") do
    %{pipeline_editor_authorized?: true, pipeline_editor_draft: pipeline_editor_invalid_draft()}
  end

  defp pipeline_editor_fixture_payload("pipeline_configuration_editor_valid_changes") do
    %{pipeline_editor_authorized?: true, pipeline_editor_draft: pipeline_editor_valid_draft()}
  end

  defp pipeline_editor_fixture_payload(_fixture), do: %{}

  defp pipeline_editor_base_draft do
    %{
      "version" => 1,
      "name" => "perme8-core",
      "merge_queue" => %{"strategy" => "merge_queue"},
      "stages" => [
        %{
          "id" => "ready",
          "label" => "Ready",
          "type" => "triage",
          "triggers" => ["on_ticket_play"],
          "depends_on" => [],
          "ticket_concurrency" => 1,
          "steps" => [%{"name" => "queue", "run" => "noop", "retries" => 0, "env" => %{}}],
          "gates" => []
        },
        %{
          "id" => "in-progress",
          "label" => "In Progress",
          "type" => "verification",
          "triggers" => [],
          "depends_on" => ["ready"],
          "ticket_concurrency" => 1,
          "steps" => [
            %{
              "name" => "test",
              "run" => "mix test",
              "timeout_seconds" => 300,
              "retries" => 0,
              "env" => %{},
              "depends_on" => []
            }
          ],
          "gates" => []
        },
        %{
          "id" => "in-review",
          "label" => "In Review",
          "type" => "review",
          "triggers" => [],
          "depends_on" => ["in-progress"],
          "ticket_concurrency" => 1,
          "steps" => [
            %{
              "name" => "review",
              "run" => "mix credo",
              "retries" => 0,
              "env" => %{},
              "depends_on" => []
            }
          ],
          "gates" => []
        },
        %{
          "id" => "warm-pool",
          "label" => "Warm Pool",
          "type" => "warm_pool",
          "schedule" => %{"cron" => "*/5 * * * *"},
          "triggers" => ["on_warm_pool"],
          "depends_on" => [],
          "ticket_concurrency" => 1,
          "warm_pool" => %{
            "target_count" => 2,
            "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
            "readiness" => %{"strategy" => "command_success"}
          },
          "steps" => [
            %{
              "name" => "prestart",
              "run" => "scripts/warm_pool.sh",
              "retries" => 0,
              "env" => %{},
              "depends_on" => []
            }
          ],
          "gates" => []
        }
      ]
    }
  end

  defp pipeline_editor_structure_draft do
    pipeline_editor_base_draft()
    |> put_in(["stages"], [
      %{
        "id" => "legacy-cleanup",
        "label" => "Legacy Cleanup",
        "type" => "verification",
        "triggers" => ["on_ticket_play"],
        "depends_on" => [],
        "ticket_concurrency" => 1,
        "steps" => [
          %{
            "name" => "cleanup",
            "run" => "mix clean",
            "retries" => 0,
            "env" => %{},
            "depends_on" => []
          }
        ],
        "gates" => []
      },
      %{
        "id" => "warm-pool",
        "label" => "Warm Pool",
        "type" => "warm_pool",
        "schedule" => %{"cron" => "*/5 * * * *"},
        "triggers" => ["on_warm_pool"],
        "depends_on" => [],
        "ticket_concurrency" => 1,
        "warm_pool" => %{
          "target_count" => 2,
          "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
          "readiness" => %{"strategy" => "command_success"}
        },
        "steps" => [
          %{
            "name" => "prestart",
            "run" => "scripts/warm_pool.sh",
            "retries" => 0,
            "env" => %{},
            "depends_on" => []
          }
        ],
        "gates" => []
      }
    ])
  end

  defp pipeline_editor_invalid_draft do
    pipeline_editor_base_draft()
    |> put_in(["stages", Access.at(1), "steps", Access.at(0), "run"], nil)
  end

  defp pipeline_editor_valid_draft do
    pipeline_editor_base_draft()
    |> put_in(["stages", Access.at(1), "steps", Access.at(0), "run"], "mix test --trace")
  end

  defp pipeline_kanban_fixture_tickets(mode \\ :default) do
    rollup_tickets =
      if mode == :rollup do
        [
          lifecycle_fixture_ticket(410, "Rollup ticket one", lifecycle_stage: "in_progress"),
          lifecycle_fixture_ticket(411, "Rollup ticket two", lifecycle_stage: "in_progress"),
          lifecycle_fixture_ticket(412, "Rollup ticket three", lifecycle_stage: "in_progress")
        ]
      else
        []
      end

    [
      lifecycle_fixture_ticket(402, "Add pipeline kanban row", lifecycle_stage: "in_progress"),
      lifecycle_fixture_ticket(403, "Prepare review state", lifecycle_stage: "in_review"),
      lifecycle_fixture_ticket(404, "CI verification", lifecycle_stage: "ci_testing"),
      lifecycle_fixture_ticket(405, "Deploy release", lifecycle_stage: "deployed")
    ] ++ rollup_tickets
  end

  def lifecycle_fixture_ticket(number, title, attrs) do
    defaults = %{
      id: number,
      number: number,
      title: title,
      state: "open",
      labels: ["agents"],
      lifecycle_stage: "open",
      lifecycle_stage_entered_at: DateTime.utc_now() |> DateTime.truncate(:second),
      lifecycle_events: [],
      sub_tickets: [],
      position: 0,
      session_state: "idle",
      task_status: nil,
      associated_task_id: nil,
      associated_container_id: nil
    }

    defaults
    |> Map.merge(Map.new(attrs))
    |> Ticket.new()
  end
end
