# Ticket #511: Pipeline Configuration UI Architectural Plan

## App Ownership

- Owning app: `agents`
- Owning Repo: `Agents.Repo`
- Domain path: `apps/agents/lib/agents/pipeline/`
- Web path: `apps/agents_web/lib/live/dashboard/`
- Migration path: `apps/agents/priv/repo/migrations/`
- Tests path: `apps/agents/test/agents/pipeline/` and `apps/agents_web/test/live/dashboard/`

## Scope

Add a dashboard pipeline configuration editor that renders pipeline stages as editable cards, lets operators change stage and step configuration without hand-editing YAML, validates changes before save, and persists valid updates back to `Agents.Repo`.

## Current Baseline

- `Agents.Pipeline.Application.UseCases.LoadPipeline` already loads the persisted pipeline document through `Agents.Pipeline.Infrastructure.YamlParser`.
- `YamlParser` already performs schema-style validation and builds `PipelineConfig`, `Stage`, `Step`, `Gate`, and `DeployTarget` value objects.
- `PipelineConfig` is currently read-only from the application's perspective: there is no update use case, no YAML serializer, and no facade entrypoint for config edits.
- The sessions dashboard already has pipeline-aware UI patterns through `PipelineKanbanState`, `PipelineKanbanHandlers`, and `PipelineKanbanComponents`.
- The dashboard template already renders a bottom pipeline section, so the new editor should fit into the existing dashboard composition rather than introduce a second disconnected pipeline surface.
- The checked-in YAML currently has three actual pipeline stages (`warm-pool`, `test`, `deploy`) while the dashboard kanban renders ticket-facing lifecycle columns (`ready`, `in_progress`, `in_review`, `ci_testing`, `merge_queue`, `deployed`).

## Key Design Decisions

- Treat the editor as a config-management surface for the persisted pipeline document, not an editor for the ticket-facing kanban abstraction.
- Reuse `YamlParser` as the canonical validation gate after merging edits; do not duplicate validation rules in LiveView.
- Introduce a dedicated `YamlWriter` infrastructure module that serializes the same normalized shape `YamlParser` expects so parse/write/parse round-trips stay stable.
- Keep the LiveView state in a UI-friendly editable map/tree and convert it at save time through `UpdatePipelineConfig`.
- Use the same parsed pipeline config as the source of truth for both editor card order and any pipeline-backed kanban ordering so the acceptance criterion about order stays aligned with the persisted pipeline document.

## Proposed Additions

- New domain-facing use case:
  - `Agents.Pipeline.Application.UseCases.UpdatePipelineConfig`
- New infrastructure writer:
  - `Agents.Pipeline.Infrastructure.YamlWriter`
- New facade delegates in `Agents.Pipeline` for loading editable config and saving updates
- New dashboard component module:
  - `AgentsWeb.DashboardLive.Components.PipelineEditorComponents`
- New dashboard state/handler support for draft pipeline edits, validation errors, reorder operations, and save feedback
- New LiveView tests and unit tests covering merge, validation, serialization, and editor interactions

## Data Shape Recommendation

Use a normalized editable payload in the UI and use case layers:

- top-level:
  - `version`
  - `name`
  - `description`
  - `merge_queue`
  - `deploy_targets`
  - `stages`
- each stage:
  - `client_id` (UI-only stable identifier for drag/reorder)
  - `id`
  - `type`
  - `deploy_target`
  - `schedule`
  - `config`
  - `steps`
  - `gates`
- warm pool stage config lives inside `config["warm_pool"]`
- each step:
  - `client_id` (UI-only)
  - `name`
  - `run`
  - `timeout_seconds`
  - `retries`
  - `env`

`UpdatePipelineConfig` should accept partial updates against this shape, merge them into the currently loaded config, convert the result into the YAML parser input shape, validate by reparsing, and only then write to disk.

## Merge and Validation Strategy

1. Load the current config from disk.
2. Convert the `PipelineConfig` struct tree into a plain YAML-compatible map.
3. Apply the partial update to that map with explicit merge helpers for:
   - root metadata
   - deploy targets
   - stage list reorder/add/remove/update
   - step list reorder/add/remove/update within a stage
   - warm pool nested config
4. Serialize the merged map to YAML with `YamlWriter`.
5. Re-parse the YAML string with `YamlParser.parse_string/1`.
6. If parsing fails, return actionable validation errors and do not write the file.
7. If parsing succeeds, persist the YAML-backed document in `Agents.Repo` and return the validated `PipelineConfig` plus a UI-ready projection.

This keeps one validation source of truth and guarantees the writer never persists a config the parser would reject.

## LiveView Integration Direction

- Extend `AgentsWeb.DashboardLive.Index` assigns with:
  - `:pipeline_config`
  - `:pipeline_editor_draft`
  - `:pipeline_editor_errors`
  - `:pipeline_editor_saving`
  - `:pipeline_editor_saved_at`
- Add editor-specific events for:
  - field change
  - add/remove stage
  - move stage up/down
  - add/remove step
  - move step up/down
  - save config
- Keep reorder mechanics button-driven first (`move up` / `move down`) so tests stay deterministic; drag-and-drop can remain a follow-up.
- Render the editor as stage cards using a dedicated component module and mount it in the dashboard near the existing pipeline section rather than scattering card markup through `index.html.heex`.
- Keep validation and persistence in the use case; handlers should only manage draft state and invoke the facade.

## Risks and Ambiguities

- The ticket asks for "kanban column order reflects the pipeline stage order", but the current kanban shows ticket lifecycle stages, not literal pipeline config stages. The implementation should align ordering only for the real pipeline-backed stages and avoid regressing the existing ticket-facing kanban behavior.
- YAML formatting should be deterministic enough to avoid noisy diffs. The writer should preserve semantic ordering even if comments/whitespace are not preserved.
- Reorder operations need stable UI-only ids so unsaved draft items can move safely before they have durable names.
- `conditions` are mentioned in the ticket, but the current parser does not model them on `Step`. The plan should treat them as a new optional step field that must be added consistently to parser, writer, entity projection, and tests.

## RED / GREEN / REFACTOR Plan

### Phase 1: Extend the pipeline config model for editing round-trips ✓

- [x] RED: add parser/entity tests for editable step and stage fields missing from the current model, especially `conditions` and nested warm-pool config round-trips
- [x] RED: add writer tests that assert a validated config serializes to YAML in the expected field order and reparses cleanly
- [x] GREEN: extend `Step` and any related projections to carry `conditions` and other editable step fields required by the ticket
- [x] GREEN: implement `YamlWriter` to convert a normalized config map or `PipelineConfig` struct into YAML with stable ordering for version, pipeline metadata, merge queue, deploy targets, stages, steps, and gates
- [x] GREEN: add conversion helpers between `PipelineConfig` structs and editable plain maps so the UI/use case can work with a serializable shape
- [x] REFACTOR: isolate YAML field ordering and struct-to-map conversion in private infrastructure helpers so parser and writer stay symmetric

### Phase 2: Add the update use case and facade support ✓

- [x] RED: add `UpdatePipelineConfig` tests for partial stage edits, warm-pool edits, add/remove/reorder stage operations, add/remove/reorder step operations, and invalid updates returning clear errors
- [x] RED: add use-case tests proving invalid merged configs never write to disk
- [x] GREEN: implement `Agents.Pipeline.Application.UseCases.UpdatePipelineConfig` with injected parser, writer, and file IO dependencies for testability
- [x] GREEN: add facade delegates in `Agents.Pipeline` for fetching editor config and saving updates from `agents_web`
- [x] GREEN: return a validated config plus UI-ready metadata/errors that the dashboard can render without recomputing validation state client-side
- [x] REFACTOR: extract merge helpers by level (root/stage/step) so update paths remain readable and future config sections can be added safely

### Phase 3: Build dashboard editor state and components ✓

- [x] RED: add LiveView tests proving the pipeline editor renders real pipeline stages as editable cards in config order, including the warm-pool card
- [x] RED: add handler tests for editing step fields, editing warm-pool fields, and add/remove/reorder stage and step interactions
- [x] GREEN: create `AgentsWeb.DashboardLive.Components.PipelineEditorComponents` with focused function components for editor shell, stage cards, step cards, env/conditions editors, validation banners, and save actions
- [x] GREEN: extend `AgentsWeb.DashboardLive.Index` and a dedicated handler/state module to load pipeline config into assigns, track draft edits, and project use-case validation errors into the UI
- [x] GREEN: mount the editor in `apps/agents_web/lib/live/dashboard/index.html.heex` so it complements the existing pipeline view and works on desktop/mobile layouts
- [x] REFACTOR: centralize reusable editor field naming/test ids so feature tests and LiveView tests stay stable as card markup evolves

### Phase 4: Save flow, feedback, and regression coverage ✓

- [x] RED: add LiveView tests proving invalid saves show clear errors and keep the draft intact
- [x] RED: add LiveView tests proving valid saves show confirmation and refresh the dashboard/editor from the persisted config
- [x] RED: add an integration-style test that updates the persisted pipeline document through the use case and verifies the saved YAML reparses with the expected structure
- [x] GREEN: wire the save handler to call `UpdatePipelineConfig`, persist to the configured path, and surface success/error flash state in the editor
- [x] GREEN: ensure the editor refreshes any pipeline-derived UI state after save so displayed stage order stays aligned with the persisted config
- [x] REFACTOR: funnel post-save refresh into a single helper that updates editor assigns and any dependent pipeline UI from the returned validated config

## Testing Strategy

- Unit-test `YamlWriter` for field ordering, nested warm-pool serialization, env map serialization, optional field omission, and parse/write/parse round-trips
- Unit-test `UpdatePipelineConfig` with temporary files and injected doubles for parser/writer dependencies
- Extend parser/entity tests where the ticket requires new editable fields such as `conditions`
- Add LiveView tests around `AgentsWeb.DashboardLive.Index` for:
  - editor card rendering and order
  - step editing preview/draft state
  - warm-pool editing
  - add/remove/reorder stage and step actions
  - invalid save errors
  - successful save feedback
- Keep browser feature coverage fixture-driven through the new feature file `apps/agents_web/test/features/dashboard/pipeline-configuration-ui.browser.feature`

## Suggested Implementation Order

1. Extend the editable config shape and add parser/writer round-trip coverage
2. Implement `YamlWriter` and `UpdatePipelineConfig`
3. Expose facade entrypoints and a UI-ready config projection
4. Add dashboard editor state and handlers
5. Extract/render editor card components and wire save flow
6. Run targeted `agents` and `agents_web` tests, then broader regression checks
