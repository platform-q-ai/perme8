# Pipeline Architecture

## Overview

The agents pipeline is a DB-driven, event-driven orchestration model for moving work through
stages such as development, verification, merge, and deployment. It is no longer defined by a
checked-in YAML file and it no longer treats deploy, warm pool, or merge queue as special runtime
subsystems.

The pipeline now works through a small set of core primitives:

- `stages` - top-level orchestration nodes
- `steps` - executable work units within a stage
- `gates` - runtime-significant stage-boundary progression checks
- `transitions` - explicit outcome-based routing rules
- `triggers` - external events that start entry stages
- `ticket_concurrency` - persisted stage admission limits

## Persistence Model

Pipeline configuration is persisted in `Agents.Repo` through normalized tables rather than a raw
config blob.

The core persisted records are:

- `pipeline_configs`
- `pipeline_stages`
- `pipeline_steps`
- `pipeline_gates`
- `pipeline_transitions`

Pipeline execution is persisted through pipeline runs, including queue/admission state and stage
results.

## Runtime Primitives

### Stages

A stage is the main orchestration node. A stage can declare:

- `id`
- `type`
- `triggers`
- `depends_on`
- `ticket_concurrency`
- `ticket_stage`
- `steps`
- `gates`
- `transitions`

Stages are first-class and own ticket concurrency. A stage can be a development stage, a merge
queue stage, a deployment stage, or a scheduled stage without the core runtime needing to know
special semantics for any of those labels.

### Steps

Steps are executable work units. Steps can run arbitrary bash commands and default to sequential
execution when explicit dependencies are omitted.

The engine does not treat deploy or warm-pool steps specially. Those behaviors live in step
commands and stage config.

### Gates

Gates are first-class stage-boundary progression checks.

The execution order is:

1. enter stage
2. run steps
3. evaluate gates
4. route using transitions

Gates can produce:

- `passed`
- `blocked`
- `failed`

Built-in runtime gate support currently includes:

- `quality`
- `manual_approval`
- `time_window`
- `environment_ready`

### Transitions

Transitions are explicit outcome-routing rules.

Each transition can describe:

- `on`
- `to_stage`
- `reason`
- `ticket_stage_override`
- `ticket_reason`

This allows flows like:

- `verify_local failed -> develop`
- `merge_queue passed -> deploy`
- `deploy failed -> deploy`

without relying on implicit list order.

## Triggers and Entry Stages

Entry stages start from explicit trigger events such as:

- `on_ticket_play`
- `on_merge_window`
- `on_warm_pool`

Downstream stages progress through transitions and completion outcomes rather than needing their
own external trigger source.

## Concurrency and Queueing

Stage concurrency is persisted and event-driven.

- `ticket_concurrency: nil` means unlimited
- `ticket_concurrency: 0` means always queue
- `ticket_concurrency: N` means only `N` active runs may occupy that stage at once

When capacity is exhausted, the pipeline run is persisted with queue metadata. This makes stage
admission crash-safe across app restarts.

Pipeline run queue-related fields include:

- `queued_stage_id`
- `queue_reason`
- `enqueued_at`

## Ticket Lifecycle Projection

Ticket lifecycle is projected from pipeline execution.

The pipeline run is execution truth. The ticket is the human-facing projection.

Projection is driven by:

- stage-level `ticket_stage`
- transition-level `ticket_stage_override`
- transition-level `ticket_reason`

Tickets also store ownership metadata so lifecycle projection does not bounce between competing
runs:

- `lifecycle_owner_run_id`
- `lifecycle_reason`

The ownership policy favors active runs over terminal runs and newer runs over older runs.

## Loop and Retry Hardening

Pipeline runs track execution history to reduce runaway loops.

Persisted run fields include:

- `attempt_count`
- `stage_attempt_counts`
- `visited_stage_ids`

The runtime enforces configurable caps for:

- total pipeline attempts
- attempts per stage

## Modeling Non-Special Flows

### Merge Queue

Merge queue is modeled as a normal stage.

- it can hold work via `ticket_concurrency: 0`
- it can be released by `on_merge_window`
- batching and merge logic live in steps and stage config

### Deploy

Deploy is modeled as a normal stage with ordinary steps and gates.

### Warm / Scheduled Flows

Scheduled flows are normal stages triggered by scheduler-emitted events. The scheduler is only an
event source, not a workflow-specific subsystem.

## Current Architectural Shape

The current architecture supports:

- explicit entry stages
- explicit outcome routing
- stage-owned queueing
- first-class stage gates
- ordinary merge/deploy/scheduled stages
- ticket lifecycle projection from execution

What remains more policy-oriented than structural:

- richer batch semantics
- stronger operator visibility
- deeper gate vocabulary and retry policy refinement
