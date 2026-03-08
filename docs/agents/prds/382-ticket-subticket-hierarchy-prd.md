# PRD: Ticket Domain Entity with Subticket Hierarchy and GitHub Sub-Issue Sync (#382)

## Source
- Ticket: #382
- Title: `feat: extend ticket entity with subticket hierarchy and GitHub sub-issue sync`

## Summary
- **Problem**: The ticket concept in the Sessions bounded context has no domain entity — it exists solely as an Ecto schema (`ProjectTicketSchema`) with business logic scattered across the `Sessions` facade and LiveView helpers. There is also no support for parent-child (subticket) relationships, meaning GitHub sub-issues cannot be synced or rendered hierarchically.
- **Value**: Introducing a proper `Ticket` domain entity aligns with clean architecture principles already established by `Task`, eliminating architectural debt. Adding subticket hierarchy enables teams to decompose large tickets into trackable sub-issues synced from GitHub. This also lays the groundwork for follow-up work on ticket dependency tracking.
- **Users**: Developers using the Sessions UI to triage, queue, and track work on GitHub issues.

## App Ownership
- Owning domain app: `agents`
- Owning interface app: `agents_web`
- Owning Repo: `Agents.Repo`

## User Stories

1. As a developer using the Sessions UI, I want tickets represented as proper domain entities so that ticket business logic is encapsulated, testable, and decoupled from infrastructure concerns.
2. As a developer, I want to see subtickets nested under their parent ticket in the triage column so that I can understand the hierarchical breakdown of work at a glance.
3. As a developer, I want GitHub sub-issue relationships automatically synced to the local database so that the hierarchy stays current without manual intervention.
4. As a developer viewing a parent ticket's detail panel, I want to see a list of its subtickets so that I can assess the status of the decomposed work.
5. As a developer, I want to reorder subtickets within their parent group using existing drag-and-drop so that I can prioritize sub-work independently.
6. As a developer, I want visual indicators on parent tickets showing how many subtickets they have, and what state those subtickets are in, so that I can quickly assess progress.

## Functional Requirements

### Must Have (P0)

#### 1. Ticket Domain Entity

1. Create `Agents.Sessions.Domain.Entities.Ticket` as a pure struct following the `Task` entity pattern — no Ecto, no database concerns.
2. Define all ticket fields on the entity: `id`, `number`, `external_id`, `title`, `body`, `status`, `state`, `priority`, `size`, `labels`, `url`, `position`, `sync_state`, `last_synced_at`, `last_sync_error`, `remote_updated_at`, `parent_ticket_id`, `sub_tickets` (list of child `Ticket` entities), `created_at`, `inserted_at`, `updated_at`.
3. Include a `new/1` factory function for creating entities from attribute maps.
4. Include a `from_schema/1` function to convert `ProjectTicketSchema` records to domain entities, with recursive conversion for preloaded `sub_tickets` associations.
5. Define a `@type t` typespec for the entity.
6. Define domain logic query functions: `open?/1`, `closed?/1`, `has_sub_tickets?/1`, `root_ticket?/1`, `sub_ticket?/1`.
7. Refactor the `Sessions` facade to return `Ticket` domain entities from `list_project_tickets/2` instead of raw schema structs or ad-hoc maps.
8. Refactor the `ProjectTicketRepository` to convert schemas to domain entities at the repository boundary.
9. Update the LiveView (`AgentsWeb.SessionsLive.Index`) and components (`ticket_card/1`) to receive and render `Ticket` domain entities instead of schema structs or ad-hoc maps.
10. Move enrichment logic (associated task/container/session state) into the domain entity or a dedicated domain service, replacing the ad-hoc `Map.merge` in the `Sessions` facade and the duplicated `re_enrich_tickets/2` in the LiveView.

#### 2. Subticket Data Model

11. Add a self-referencing `parent_ticket_id` foreign key column to the `sessions_project_tickets` table via migration — nullable, with `on_delete: :nilify_all`, following the pattern in `20260222130000_add_parent_task_to_sessions_tasks.exs`.
12. Add an index on `parent_ticket_id` for efficient child lookups.
13. Update `ProjectTicketSchema` with the `parent_ticket_id` field, a `belongs_to :parent_ticket` association pointing to itself, and a `has_many :sub_tickets` association.
14. Include `parent_ticket_id` in the schema changeset's castable fields.

#### 3. GitHub Sub-Issue Sync

15. Extend `GithubProjectClient.fetch_tickets/1` to also fetch sub-issue relationships from GitHub using the GraphQL `subIssues(first: N) { nodes { number } }` field on issue nodes.
16. Update `ProjectTicketRepository.sync_remote_ticket/2` to accept and persist `parent_ticket_id` (or a parent issue number that can be resolved to an ID).
17. Update `TicketSyncServer.poll_tickets/1` to resolve parent-child relationships after syncing individual tickets — match sub-issue numbers to persisted ticket IDs and set `parent_ticket_id`.
18. Handle the edge case where a parent ticket has not yet been synced (defer child linking until parent is available).
19. Handle orphaned subtickets when a parent is deleted (the `on_delete: :nilify_all` constraint makes them top-level).
20. Handle reparenting — when a sub-issue is moved to a different parent on GitHub, or promoted to top-level, the sync must update `parent_ticket_id` accordingly.
21. Guard against circular references in sub-issue data from GitHub.

#### 4. UI: Subtickets as Children of Parent Ticket

22. In the triage column, render subtickets visually nested under their parent ticket (indented or as a collapsible tree).
23. Only render root tickets (where `parent_ticket_id` is nil) at the top level; their subtickets render as children.
24. The `ticket_card` component must support a nested/child variant — either via a new `:sub_ticket` variant or a `depth` assign for visual hierarchy (indentation, reduced prominence).
25. Parent tickets must show a count or indicator of their subtickets (e.g., "3 sub-issues").
26. In the ticket detail panel (right side), display the subticket list when viewing a parent ticket.
27. When a parent ticket is closed, visually indicate the state of its subtickets (e.g., show how many are still open).

### Should Have (P1)

28. Subticket ordering should respect the existing `position`-based drag-and-drop within their parent group.
29. Collapsible parent tickets in the triage column — users can expand/collapse the subticket tree.
30. Ensure `re_enrich_tickets/2` (or its domain entity replacement) preserves parent-child relationships when refreshing from task snapshot changes.

### Nice to Have (P2)

31. Visual breadcrumb or "parent" link when viewing a subticket in the detail panel, to navigate up to the parent.
32. Filtering in the triage column to show/hide subtickets independently.

## User Workflows

### Workflow 1: Automatic hierarchy sync
1. GitHub sub-issues are created/modified on the configured repository.
2. `TicketSyncServer` polls GitHub on its regular interval.
3. `GithubProjectClient` fetches issues including sub-issue relationships.
4. `TicketSyncServer` upserts tickets and resolves `parent_ticket_id` for sub-issues.
5. Persisted tickets are broadcast via PubSub (`{:tickets_synced, tickets}`).
6. LiveView receives the broadcast, calls `Sessions.list_project_tickets/2`, receives `Ticket` domain entities with `sub_tickets` populated.
7. Triage column re-renders with hierarchical nesting.

### Workflow 2: Viewing a parent ticket
1. User clicks a parent ticket in the triage column.
2. Ticket detail panel shows the ticket body, labels, status, and a "Sub-issues" section listing child tickets with their status.
3. User can click a subticket to navigate to its detail.

### Workflow 3: Reordering subtickets
1. User drags a subticket within its parent group in the triage column.
2. `reorder_triage_tickets/1` is called with the new order.
3. Subticket positions are updated, preserving parent-child grouping.

## Data Requirements

### Capture
- `parent_ticket_id`: nullable bigint foreign key referencing `sessions_project_tickets.id`, with `on_delete: :nilify_all`
- Sub-issue numbers from GitHub GraphQL: `subIssues(first: N) { nodes { number } }` on each issue node

### Display
- Root tickets displayed at top level in triage column
- Subtickets nested under parent with visual indentation
- Parent ticket badge showing subticket count
- Subticket status indicators on parent ticket detail panel

### Relationships
- `ProjectTicketSchema` self-references: `belongs_to :parent_ticket` / `has_many :sub_tickets`
- `Ticket` domain entity: `parent_ticket_id` field + `sub_tickets` list of child `Ticket` entities

## Technical Considerations

### Affected Layers
- **Domain**: New `Ticket` entity at `apps/agents/lib/agents/sessions/domain/entities/ticket.ex`
- **Infrastructure**: Schema changes to `ProjectTicketSchema`, repository changes to `ProjectTicketRepository`, sync changes to `TicketSyncServer`, client changes to `GithubProjectClient`
- **Application**: `Sessions` facade refactored to return domain entities
- **Interface**: `AgentsWeb.SessionsLive.Index` and `session_components.ex` updated to work with domain entities

### Integration Points
- **GitHub GraphQL API**: Already used for `closeIssue`; extend to query `subIssues` on issue nodes
- **GitHub REST API**: Currently used for `fetch_tickets` (paginated issue listing); sub-issue data may require supplementing with GraphQL or using the REST sub-issues endpoint
- **PubSub**: Existing `sessions:tickets` topic for broadcasting sync results — no changes to the topic needed, but the payload structure changes from schema structs to domain entities (or the conversion happens downstream)

### Performance
- Sub-issue GraphQL queries add API calls per sync cycle; batch where possible
- Recursive `from_schema/1` conversion should handle typical depths (1-2 levels) without concern; guard against pathological nesting
- Preloading `sub_tickets` association adds a query per sync but is bounded by ticket count

### Security
- No new auth/authorization changes — tickets inherit the existing session-level access model
- GitHub token usage unchanged — same token used for sub-issue queries

## Edge Cases & Error Handling

1. **Parent not yet synced**: A sub-issue references a parent issue that hasn't been synced yet. -> **Expected**: Store the sub-issue without `parent_ticket_id`; on the next sync cycle when the parent is present, resolve and set the relationship.
2. **Parent deleted from GitHub**: A parent issue is deleted, leaving orphaned sub-issues. -> **Expected**: `on_delete: :nilify_all` promotes sub-issues to top-level tickets automatically.
3. **Circular references**: GitHub data somehow contains circular sub-issue chains. -> **Expected**: Detect cycles during sync (e.g., depth limit or visited-set check) and log a warning; do not set `parent_ticket_id` for the cycle-creating link.
4. **Reparenting**: A sub-issue is moved to a different parent on GitHub. -> **Expected**: Sync updates `parent_ticket_id` to the new parent's ID (or nil if promoted to top-level).
5. **Sub-issue not in synced repo**: A sub-issue belongs to a different repository. -> **Expected**: Ignore cross-repo sub-issues; only track sub-issues within the configured repository.
6. **Deeply nested sub-issues**: GitHub supports multi-level sub-issue nesting. -> **Expected**: Support at least 2 levels of nesting in the domain model; UI may flatten beyond a practical depth.
7. **Empty sub-issues list**: Parent ticket has no sub-issues. -> **Expected**: `sub_tickets` is an empty list `[]`; UI shows no sub-issue section.
8. **Concurrent sync and UI access**: Sync updates parent-child relationships while user is viewing tickets. -> **Expected**: PubSub broadcast triggers LiveView re-render with fresh data; no stale hierarchy displayed after broadcast.

## Acceptance Criteria

- [ ] `Agents.Sessions.Domain.Entities.Ticket` exists as a pure struct with `new/1`, `from_schema/1`, `@type t`, and domain query functions (`open?/1`, `closed?/1`, `has_sub_tickets?/1`, `root_ticket?/1`, `sub_ticket?/1`)
- [ ] `Ticket` entity has no Ecto or infrastructure dependencies (pure domain struct)
- [ ] `ProjectTicketSchema` has `parent_ticket_id` field with `belongs_to :parent_ticket` and `has_many :sub_tickets` associations
- [ ] Migration adds `parent_ticket_id` column with self-referencing foreign key, nullable, `on_delete: :nilify_all`, and an index
- [ ] `Sessions.list_project_tickets/2` returns `Ticket` domain entities (not schema structs or ad-hoc maps)
- [ ] Enrichment logic (associated task, container, session state) is encapsulated in the domain layer, not scattered across facade and LiveView
- [ ] LiveView and components receive and render `Ticket` domain entities
- [ ] `GithubProjectClient` fetches sub-issue relationships from GitHub
- [ ] `TicketSyncServer` persists parent-child relationships based on GitHub sub-issue data
- [ ] Sync correctly handles: parent not yet synced, reparenting, orphaned subtickets, circular references
- [ ] Triage column renders subtickets nested under their parent ticket with visual indentation
- [ ] Parent tickets display a subticket count indicator
- [ ] Ticket detail panel shows subticket list when viewing a parent ticket
- [ ] Subticket ordering respects position-based drag-and-drop within parent group
- [ ] When a parent ticket is closed, subticket states are visually indicated
- [ ] Existing ticket tests continue to pass with the domain entity refactor
- [ ] `re_enrich_tickets` (or replacement) preserves parent-child relationships

## Codebase Context

### Reference Pattern: Task Domain Entity
- **Entity**: `apps/agents/lib/agents/sessions/domain/entities/task.ex` — pure struct with `new/1`, `from_schema/1`, `@type t`, `valid_statuses/0`, no Ecto dependencies. This is the exact pattern to replicate for `Ticket`.

### Affected Files
| File | Role | Changes |
|------|------|---------|
| `apps/agents/lib/agents/sessions/domain/entities/ticket.ex` | Domain entity | **New file** — pure `Ticket` struct |
| `apps/agents/lib/agents/sessions/infrastructure/schemas/project_ticket_schema.ex` | Ecto schema | Add `parent_ticket_id`, `belongs_to`, `has_many` |
| `apps/agents/lib/agents/sessions/infrastructure/repositories/project_ticket_repository.ex` | Repository | Add preloading of `sub_tickets`, convert to domain entities, accept `parent_ticket_id` in sync |
| `apps/agents/lib/agents/sessions/infrastructure/ticket_sync_server.ex` | Sync server | Resolve parent-child relationships after sync, handle edge cases |
| `apps/agents/lib/agents/sessions/infrastructure/clients/github_project_client.ex` | GitHub client | Add sub-issue GraphQL query, return parent/sub-issue data |
| `apps/agents/lib/agents/sessions.ex` | Facade | Return `Ticket` entities from `list_project_tickets/2`, move enrichment to domain layer |
| `apps/agents_web/lib/live/sessions/index.ex` | LiveView | Work with `Ticket` entities, update `re_enrich_tickets` or replace with domain service call |
| `apps/agents_web/lib/live/sessions/index.html.heex` | Template | Render hierarchical ticket tree in triage column |
| `apps/agents_web/lib/live/sessions/components/session_components.ex` | Components | Update `ticket_card/1` to support depth/nesting, add subticket indicators |
| `apps/agents/priv/repo/migrations/YYYYMMDDHHMMSS_add_parent_ticket_id_to_project_tickets.exs` | Migration | **New file** — add `parent_ticket_id` column and index |

### Existing Migration Pattern
The `parent_task_id` self-reference migration (`20260222130000_add_parent_task_to_sessions_tasks.exs`) provides the exact pattern:
```elixir
alter table(:sessions_project_tickets) do
  add(:parent_ticket_id, references(:sessions_project_tickets, on_delete: :nilify_all))
end
create(index(:sessions_project_tickets, [:parent_ticket_id]))
```

### GitHub GraphQL
Sub-issues are available via `subIssues(first: N) { nodes { number } }` on issue nodes. The client already uses GraphQL for `closeIssue` (mutation) and `fetch_issue_id` (query), so the infrastructure for GraphQL queries exists.

### Current Enrichment Flow
1. `Sessions.list_project_tickets/2` (facade, line 178) loads tickets from `ProjectTicketRepository.list_all()`, matches each to a task by extracting ticket numbers from task instructions, and merges enrichment fields (`associated_task_id`, `associated_container_id`, `session_state`, `task_status`, `task_error`) via `Map.merge`.
2. `AgentsWeb.SessionsLive.Index.re_enrich_tickets/2` (LiveView, line 2004) duplicates this logic for in-memory re-enrichment when tasks change without a full DB reload.
3. Both functions return ad-hoc maps (schema structs merged with extra keys), not domain entities.

## Out of Scope

- **Ticket dependencies**: A `ticket_dependencies` join table tracking `depends_on` / `blocked_by` relationships between tickets. This is a planned follow-up feature.
- **Dependency gate**: Logic preventing a ticket from being picked up for implementation until all its dependency tickets are completed (closed).
- **Dependency UI**: Visual indicators of blocked/unblocked status and dependency chains in the triage column or detail panel.
- **Cross-repository sub-issues**: Sub-issues that reference issues in other GitHub repositories.
- **User-created sub-issue relationships**: The hierarchy is read-only from GitHub; users cannot create parent-child relationships from the Perme8 UI.

## Open Questions

- [ ] Should the GitHub sub-issue fetch use a separate GraphQL query per issue, or a single bulk query that fetches all issues with their sub-issues in one call? (Performance vs. API complexity trade-off.)
- [ ] What is the maximum practical nesting depth to support in the UI? GitHub supports arbitrary nesting, but the triage column has limited horizontal space. Recommend capping visual nesting at 2 levels.
- [ ] Should closed subtickets be hidden by default under their parent, or always shown? Current status filter applies globally — should it also apply within parent-child groups?
- [ ] When a parent ticket is dragged in the triage column, should its subtickets move with it (as a group), or can they be reordered independently?
