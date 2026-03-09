# Ticket Template

This template is used by the `ticket` agent to create comprehensive tickets that feed into the `architect` agent for implementation planning.

## Purpose

A ticket serves as a single source of truth for feature requirements, capturing:
- **What** needs to be built (functional requirements)
- **Why** it's being built (business value, user needs)
- **Who** it's for (target users, stakeholders)
- **Constraints** (performance, security, business rules)
- **Success criteria** (how we measure success)

The ticket does NOT specify **how** to build it — no code, no file paths, no architecture decisions. That's the architect's job.

## Key Principle: Conceptual Only

Tickets describe **behaviours and expectations**, never implementation details. This separation ensures:
- Requirements are understood independently of any technical approach
- The architect has freedom to choose the best implementation strategy
- Tickets remain useful even if the technology stack changes

**Never include in a ticket**: code snippets, file paths, module/class names, database table names, framework-specific terminology (e.g., "Ecto schema", "LiveView", "context module"), architecture layer references, or migration details.

**Always include in a ticket**: user behaviours, system responses, data the user sees or provides, validation rules in plain language, error messages, and measurable outcomes.

## Ticket Detail Levels

**All work requires a ticket (GitHub issue).** The level of detail varies by scope:

**Full detail** (use the complete template below):
- Feature requirements are unclear or complex
- Multiple stakeholders need alignment
- Feature spans multiple areas of the product

**Lightweight** (a concise issue with acceptance criteria):
- Requirements are simple and well-understood
- Small bug fix or minor enhancement
- Iterating on existing functionality

---

## Ticket Template Structure

### 1. Executive Summary

**Feature Name**: [Clear, concise name for the feature]

**Problem Statement**: [What problem does this solve? What pain point are users experiencing?]

**Business Value**: [Why is this important? What's the expected impact?]

**Target Users**: [Who will use this feature? User personas or roles]

---

### 2. User Stories

**Primary User Story**:
```
As a [user type],
I want to [action],
so that [benefit/value].
```

**Additional User Stories**:
- As a [user type], I want to [action], so that [benefit].
- As a [user type], I want to [action], so that [benefit].
- As a [user type], I want to [action], so that [benefit].

**User Personas** (if applicable):
- **[Persona Name]**: [Description, goals, pain points]

---

### 3. Functional Requirements

#### Core Functionality

**Must Have (P0)** - Critical for MVP:
1. [Behaviour description — what the system should do, not how]
2. [Behaviour description]

**Should Have (P1)** - Important but not blocking:
1. [Behaviour description]

**Nice to Have (P2)** - Future enhancements:
1. [Behaviour description]

#### User Workflows

**Workflow 1: [Workflow Name]**
1. User navigates to [location in the product]
2. User [action]
3. System [response/feedback]
4. User [action]
5. System [final state/result]

**Workflow 2: [Workflow Name]**
1. [Step-by-step user journey]

#### Data Requirements

**Data to Capture** (inputs from users):
| Field | Type | Required? | Validation Rules | Notes |
|-------|------|-----------|------------------|-------|
| [field] | [text/number/date/etc.] | Yes/No | [plain-language rules] | [context] |

**Data to Display** (outputs to users):
| Information | When Shown | Format |
|-------------|------------|--------|
| [what the user sees] | [under what conditions] | [how it appears] |

**Data Relationships**:
- [Concept A] belongs to [Concept B]
- [Concept C] has many [Concept D]

---

### 4. Constraints

#### Performance
- **Response Time**: [Target latency, e.g., "search results appear within 200ms"]
- **Throughput**: [Volume, e.g., "support 100 concurrent users"]
- **Data Volume**: [Scale, e.g., "handle up to 10,000 products"]
- **Real-time Updates**: [Latency, e.g., "changes visible to other users within 1 second"]

#### Security
- **Authentication**: [Who must be logged in? Any SSO/token requirements?]
- **Authorization**: [Who can access what? Role-based? Owner-only?]
- **Data Privacy**: [PII? Encryption needs? Compliance requirements?]
- **Input Validation**: [What inputs need sanitization? File upload restrictions?]

#### Integration
- **External Services**: [Third-party services this must work with, their reliability, and fallback behaviour]
- **Existing Features**: [Other parts of the product this must integrate with]

---

### 5. Non-Functional Requirements

#### Reliability
- [Uptime requirements?]
- [What happens if an external service is unavailable?]

#### Accessibility
- [WCAG compliance level?]
- [Screen reader support?]
- [Keyboard navigation?]

#### Observability
- [What should be monitored?]
- [What alerts should fire?]

---

### 6. User Interface Requirements

#### User Experience Goals
- [Goal 1: e.g., "minimize clicks to complete action"]
- [Goal 2: e.g., "provide clear feedback at each step"]

#### Key Interactions
- [Interaction pattern 1: e.g., "drag-and-drop file upload"]
- [Interaction pattern 2: e.g., "inline editing with auto-save"]

#### Responsive Design
- [ ] Desktop support required
- [ ] Mobile support required
- [ ] Tablet support required

#### Visual Design Notes
- [Brand guidelines to follow?]
- [Existing design patterns to match?]
- [Design mockups available?]

---

### 7. Edge Cases & Error Handling

#### Known Edge Cases

**Edge Case 1**: [Scenario description]
- **Expected Behaviour**: [What should happen?]
- **Rationale**: [Why this behaviour?]

**Edge Case 2**: [Scenario description]
- **Expected Behaviour**: [What should happen?]
- **Rationale**: [Why this behaviour?]

#### Error Scenarios

**Error 1**: [e.g., "Network timeout during save"]
- **User-Facing Message**: [Friendly error message]
- **Recovery**: [What can the user do? e.g., "Retry automatically"]

**Error 2**: [e.g., "Invalid input"]
- **User-Facing Message**: [Clear validation message]
- **Recovery**: [How to correct?]

#### Boundary Conditions
- Empty state: [What does the user see when there's no data?]
- Maximum limits: [What happens when limits are reached?]
- Concurrent access: [What if multiple users act simultaneously?]

---

### 8. Acceptance Criteria

- [ ] **AC1**: [Specific, testable criterion describing observable behaviour]
- [ ] **AC2**: [Specific, testable criterion describing observable behaviour]
- [ ] **AC3**: [Specific, testable criterion describing observable behaviour]

#### Test Scenarios

**Happy Path**:
1. **Scenario**: [Normal user flow] → **Expected**: [What the user sees/experiences]

**Edge Cases**:
1. **Scenario**: [Boundary condition] → **Expected**: [How the system responds]

**Security**:
1. **Scenario**: [Unauthorized access attempt] → **Expected**: [Access denied appropriately]

---

### 9. Dependencies & Assumptions

#### Dependencies
- [Feature or capability this depends on] - [Current status] - [Risk if unavailable]
- [Third-party service] - [Reliability] - [Fallback plan]

#### Assumptions
- **Assumption 1**: [What we're assuming about users/system]
  - **Impact if wrong**: [Consequence]

#### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| [Risk description] | [High/Med/Low] | [High/Med/Low] | [How to mitigate?] |

---

### 10. Success Metrics

- **[Metric Name]**: [Target value] - Measured by: [how tracked]
- **[Metric Name]**: [Target value] - Measured by: [how tracked]

---

### 11. Out of Scope

Explicitly list what this feature will **NOT** include to prevent scope creep:

- [Feature/capability not included]
- [Feature/capability not included]

**Rationale**: [Why these are out of scope]

---

### 12. Future Considerations

Features or enhancements to consider for **future iterations** (not MVP):

- [Future enhancement] - [Why deferred?]
- [Future enhancement] - [Why deferred?]

---

### 13. Open Questions

Questions that need resolution before implementation begins:

- [ ] **Q1**: [Question about requirements/scope]
  - **Blocker?**: [Yes/No]
  - **Owner**: [Who should answer?]

---

### 14. Approvals & Sign-Off

- [ ] **User/Stakeholder Approval** - [Name/Date]
- [ ] **Ready for Architect Review** - [Name/Date]

---

## How to Use This Template

### For the Ticket Agent

1. **Gather requirements** through structured questioning
2. **Fill in each section** with specifics from user responses — stay conceptual, describe behaviours
3. **Never include** code, file paths, module names, or architecture-layer references
4. **Flag open questions** that need resolution
5. **Return the complete ticket body** -- the calling skill creates the GitHub issue
6. **Hand off to architect** once the issue is created and approved

### For the Architect Agent

1. **Read the ticket** as source of truth for requirements (what and why)
2. **Research the codebase** to understand existing patterns and affected areas
3. **Translate behaviours** into a technical implementation plan with code, file paths, and architecture decisions
4. **Create RED-GREEN-REFACTOR cycles** for each component

### For Implementation Agents (phoenix-tdd, typescript-tdd)

- **Refer to ticket** for context on "why" this feature exists
- **Use acceptance criteria** to guide test writing
- **Check edge cases** section when writing error handling tests
- **Validate against success metrics** to ensure feature meets goals

---

## Example Ticket Excerpt

Here's an abbreviated example for a "workspace member invitation" feature:

### 1. Executive Summary

**Feature Name**: Workspace Member Invitation

**Problem Statement**: Users currently cannot invite teammates to their workspaces, forcing manual account creation and access setup.

**Business Value**: Streamlines onboarding, increases team adoption, reduces support requests for access issues.

**Target Users**: Workspace owners and administrators

### 2. User Stories

**Primary User Story**:
```
As a workspace owner,
I want to invite team members via email,
so that they can quickly join and collaborate without manual setup.
```

### 3. Functional Requirements

**Must Have (P0)**:
1. Owner can send an invitation to an email address — the invitation expires after 7 days
2. Invitee receives an email with a unique link to accept or decline
3. Accepting the invitation grants the invitee access to the workspace automatically
4. Workspace settings shows a list of pending invitations

### 8. Acceptance Criteria

- [ ] Owner can send invitation to a valid email address
- [ ] Invitee receives email with a working link
- [ ] Invitation link expires after 7 days and shows an appropriate message
- [ ] Accepting an invitation grants workspace access immediately
- [ ] Owner can see a list of pending invitations with their status

---

This template ensures comprehensive requirements gathering while maintaining a clear boundary: the **ticket** describes what the system should do and how users experience it; the **architect's plan** determines how to build it.
