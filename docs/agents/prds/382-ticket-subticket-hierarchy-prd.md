# PRD: Ticket Domain Entity with Subticket Hierarchy and GitHub Sub-Issue Sync (#382)

## Source
- Ticket: #382
- Title: `feat: extend ticket entity with subticket hierarchy and GitHub sub-issue sync`

## Summary
- **Problem**: The ticket concept in the Sessions area has no proper domain representation — business logic is scattered across multiple layers with no clear ownership. There is also no support for parent-child (subticket) relationships, meaning GitHub sub-issues cannot be synced or rendered hierarchically.
- **Value**: Introducing a proper Ticket domain concept aligns with clean architecture principles already established by the Task entity, eliminating architectural debt. Adding subticket hierarchy enables teams to decompose large tickets into trackable sub-issues synced from GitHub. This also lays the groundwork for follow-up work on ticket dependency tracking.
- **Users**: Developers using the Sessions UI to triage, queue, and track work on GitHub issues.

## User Stories

1. As a developer using the Sessions UI, I want tickets represented as proper domain concepts so that ticket business logic is encapsulated, testable, and clearly owned.
2. As a developer, I want to see subtickets nested under their parent ticket in the triage column so that I can understand the hierarchical breakdown of work at a glance.
3. As a developer, I want GitHub sub-issue relationships automatically synced so that the hierarchy stays current without manual intervention.
4. As a developer viewing a parent ticket's detail panel, I want to see a list of its subtickets so that I can assess the status of the decomposed work.
5. As a developer, I want to reorder subtickets within their parent group using existing drag-and-drop so that I can prioritise sub-work independently.
6. As a developer, I want visual indicators on parent tickets showing how many subtickets they have, and what state those subtickets are in, so that I can quickly assess progress.

## Functional Requirements

### Must Have (P0)

#### 1. Ticket as a Domain Concept

1. Tickets must be represented as a proper domain concept following the same pattern as the existing Task entity — a pure data structure with no infrastructure dependencies.
2. A ticket must carry all relevant fields: id, number, external id, title, body, status, state, priority, size, labels, url, position, sync state, last synced timestamp, last sync error, remote updated timestamp, parent ticket reference, and a list of child subtickets.
3. The system must be able to create ticket instances from attribute data and convert stored records to domain representations, including recursive conversion for subtickets.
4. The system must expose query functions to determine: is a ticket open? closed? does it have subtickets? is it a root ticket? is it a subticket?
5. Listing tickets must return proper domain representations rather than raw storage records or ad-hoc data structures.
6. Enrichment logic (associated task, container, session state) must be encapsulated in the domain layer rather than duplicated across multiple places in the system.
7. The UI must work with domain representations of tickets, not raw storage records.

#### 2. Subticket Data Model

8. Tickets must support a self-referencing parent-child relationship — a ticket can optionally belong to a parent ticket.
9. When a parent ticket is deleted, its subtickets must be promoted to top-level tickets (not deleted).
10. Efficient lookup of a ticket's children must be supported.

#### 3. GitHub Sub-Issue Sync

11. The GitHub sync process must fetch sub-issue relationships when polling for tickets.
12. Synced tickets must have their parent-child relationships persisted based on GitHub's sub-issue data.
13. The sync must resolve parent-child relationships correctly even when tickets arrive in any order.
14. If a parent ticket hasn't been synced yet, the child should be stored without a parent reference and linked on the next sync cycle when the parent becomes available.
15. If a parent ticket is removed, orphaned subtickets become top-level tickets automatically.
16. Reparenting must be supported — when a sub-issue is moved to a different parent on GitHub, or promoted to top-level, the sync must update the relationship accordingly.
17. Circular references in sub-issue data from GitHub must be detected and rejected with a warning.

#### 4. UI: Subtickets as Children of Parent Ticket

18. In the triage column, subtickets must be rendered visually nested under their parent ticket (indented or as a collapsible tree).
19. Only root tickets (those with no parent) appear at the top level; their subtickets render as children.
20. The ticket card must support a nested/child visual variant showing reduced prominence for subtickets.
21. Parent tickets must show an indicator of their subticket count (e.g., "3 sub-issues").
22. The ticket detail panel must display the subticket list when viewing a parent ticket.
23. When a parent ticket is closed, the state of its subtickets should be visually indicated (e.g., show how many are still open).

### Should Have (P1)

24. Subticket ordering should respect the existing position-based drag-and-drop within their parent group.
25. Parent tickets in the triage column should be collapsible — users can expand/collapse the subticket tree.
26. Refreshing ticket data (e.g., from task snapshot changes) must preserve parent-child relationships.

### Nice to Have (P2)

27. Visual breadcrumb or "parent" link when viewing a subticket in the detail panel, to navigate up to the parent.
28. Filtering in the triage column to show/hide subtickets independently.

## User Workflows

### Workflow 1: Automatic hierarchy sync
1. GitHub sub-issues are created or modified on the configured repository.
2. The system polls GitHub on its regular interval.
3. The system fetches issues including sub-issue relationships.
4. The system persists tickets and resolves parent-child relationships for sub-issues.
5. The UI receives notification of updated tickets.
6. The triage column re-renders with hierarchical nesting.

### Workflow 2: Viewing a parent ticket
1. User clicks a parent ticket in the triage column.
2. The ticket detail panel shows the ticket body, labels, status, and a "Sub-issues" section listing child tickets with their status.
3. User can click a subticket to navigate to its detail.

### Workflow 3: Reordering subtickets
1. User drags a subticket within its parent group in the triage column.
2. The system updates subticket positions, preserving parent-child grouping.

## Data Requirements

### Capture
- Parent ticket reference: optional reference from a ticket to its parent ticket; removing the parent promotes the child to top-level
- Sub-issue relationships from GitHub: which issues are sub-issues of which parent issues

### Display
- Root tickets displayed at top level in the triage column
- Subtickets nested under parent with visual indentation
- Parent ticket badge showing subticket count
- Subticket status indicators on the parent ticket detail panel

### Relationships
- A ticket optionally belongs to one parent ticket
- A ticket can have many child subtickets

## Constraints

### Performance
- Sub-issue fetching from GitHub adds API calls per sync cycle; should be batched where possible
- Recursive conversion of ticket hierarchies should handle typical depths (1-2 levels) without concern; guard against pathological nesting

### Security
- No new auth/authorization changes — tickets inherit the existing session-level access model
- GitHub token usage unchanged — same token used for sub-issue queries

### Integration
- **GitHub API**: Sub-issue relationships must be fetched from GitHub — the system already uses both REST and GraphQL APIs for ticket operations

## Edge Cases & Error Handling

1. **Parent not yet synced**: A sub-issue references a parent issue that hasn't been synced yet. → **Expected**: Store the sub-issue without a parent reference; link it on the next sync cycle when the parent is available.
2. **Parent deleted from GitHub**: A parent issue is deleted, leaving orphaned sub-issues. → **Expected**: Orphaned sub-issues become top-level tickets automatically.
3. **Circular references**: GitHub data contains circular sub-issue chains. → **Expected**: Detect cycles during sync and log a warning; do not create the cycle-causing link.
4. **Reparenting**: A sub-issue is moved to a different parent on GitHub. → **Expected**: Sync updates the parent reference to the new parent (or removes it if promoted to top-level).
5. **Sub-issue not in synced repo**: A sub-issue belongs to a different repository. → **Expected**: Ignore cross-repo sub-issues; only track sub-issues within the configured repository.
6. **Deeply nested sub-issues**: GitHub supports multi-level sub-issue nesting. → **Expected**: Support at least 2 levels of nesting; the UI may flatten beyond a practical depth.
7. **Empty sub-issues list**: Parent ticket has no sub-issues. → **Expected**: No sub-issue section shown in the UI.
8. **Concurrent sync and UI access**: Sync updates parent-child relationships while user is viewing tickets. → **Expected**: The UI refreshes with fresh data after a sync broadcast; no stale hierarchy displayed.

## Acceptance Criteria

- [ ] Tickets are represented as proper domain concepts with no infrastructure dependencies
- [ ] The system can determine whether a ticket is open, closed, a root ticket, a subticket, or has subtickets
- [ ] Tickets support a self-referencing parent-child relationship
- [ ] Deleting a parent promotes its subtickets to top-level (not cascade delete)
- [ ] Listing tickets returns domain representations, not raw storage records
- [ ] Enrichment logic is encapsulated in the domain layer, not duplicated across the system
- [ ] The UI renders tickets using domain representations
- [ ] The GitHub sync fetches sub-issue relationships
- [ ] Parent-child relationships are persisted correctly based on GitHub sub-issue data
- [ ] Sync correctly handles: parent not yet synced, reparenting, orphaned subtickets, circular references
- [ ] The triage column renders subtickets nested under their parent with visual indentation
- [ ] Parent tickets display a subticket count indicator
- [ ] The ticket detail panel shows a subticket list when viewing a parent ticket
- [ ] Subticket ordering respects position-based drag-and-drop within parent groups
- [ ] When a parent ticket is closed, subticket states are visually indicated
- [ ] Existing ticket functionality continues to work after the domain entity refactor
- [ ] Refreshing ticket data preserves parent-child relationships

## Out of Scope

- **Ticket dependencies**: A dependency tracking system for `depends_on` / `blocked_by` relationships between tickets. This is a planned follow-up feature.
- **Dependency gate**: Logic preventing a ticket from being picked up until all dependency tickets are completed.
- **Dependency UI**: Visual indicators of blocked/unblocked status and dependency chains.
- **Cross-repository sub-issues**: Sub-issues that reference issues in other GitHub repositories.
- **User-created sub-issue relationships**: The hierarchy is read-only from GitHub; users cannot create parent-child relationships from the UI.

## Open Questions

- [ ] Should the GitHub sub-issue fetch use a single bulk query or per-issue queries? (Performance vs. complexity trade-off.)
- [ ] What is the maximum practical nesting depth to support in the UI? GitHub supports arbitrary nesting, but the triage column has limited horizontal space. Recommend capping visual nesting at 2 levels.
- [ ] Should closed subtickets be hidden by default under their parent, or always shown? The current status filter applies globally — should it also apply within parent-child groups?
- [ ] When a parent ticket is dragged in the triage column, should its subtickets move with it (as a group), or can they be reordered independently?
