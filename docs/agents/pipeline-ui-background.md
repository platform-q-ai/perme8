# Pipeline UI Background

This document exists to brief future UI work for pipeline management in `agents_web`.

## What the UI Must Reflect

The UI must be compatible with the persisted, runtime-significant pipeline model.

That means the UI needs to understand and/or display:

- stages
- steps
- gates
- transitions
- triggers
- ticket concurrency
- queueing/blocked semantics
- ticket lifecycle projection metadata

## Current Editable Shape

At a high level, the UI-compatible editable shape is:

- top-level
  - `version`
  - `name`
  - `description`
  - `stages`
- stage
  - `id`
  - `type`
  - `schedule`
  - `triggers`
  - `depends_on`
  - `ticket_concurrency`
  - `ticket_stage`
  - `config`
  - `steps`
  - `gates`
  - `transitions`
- step
  - `name`
  - `run`
  - `timeout_seconds`
  - `retries`
  - `env`
  - `depends_on`
- gate
  - `type`
  - `required`
  - `params`
- transition
  - `on`
  - `to_stage`
  - `reason`
  - `ticket_stage_override`
  - `ticket_reason`

## UI Expectations

A compatible pipeline UI should let operators:

- view the pipeline as a graph or equivalent structured flow
- inspect how stages map to ticket lifecycle states
- inspect transitions and loopback routes
- inspect and edit stage concurrency
- inspect and edit gates and their required semantics
- inspect scheduled entry stages and cron-backed triggers
- save a definition that remains valid against the current application builder/validator

## Navigation Direction

The UI should live in a dedicated pipeline-focused module under `agents_web` and be reachable from
the agents layout sidebar rather than existing only as a sub-surface of the dashboard.

## Important Constraints

- The UI must not assume YAML/file-backed configuration
- The UI must not reintroduce special subsystem assumptions for merge queue, deploy, or warm pool
- The UI should treat those as normal stages plus runtime metadata
- The UI should remain consistent with the runtime semantics for gates, transitions, queueing, and
  ticket lifecycle projection
