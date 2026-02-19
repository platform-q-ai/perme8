# Product Requirements Document Template

This template is used by the `prd` agent to create comprehensive Product Requirements Documents that feed into the `architect` agent for implementation planning.

## Purpose

A PRD serves as a single source of truth for feature requirements, capturing:
- **What** needs to be built (functional requirements)
- **Why** it's being built (business value, user needs)
- **Who** it's for (target users, stakeholders)
- **Constraints** (technical, business, security)
- **Success criteria** (how we measure success)

The PRD does NOT specify **how** to build it (that's the architect's job).

## When to Create a PRD

**Create a PRD when:**
- Feature requirements are unclear or complex
- Multiple stakeholders need alignment
- Feature spans multiple systems or contexts
- You want to ensure nothing is missed

**Skip the PRD when:**
- Requirements are simple and well-understood
- It's a small bug fix or minor enhancement
- You're iterating on existing functionality

---

## PRD Template Structure

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
1. [Requirement description] - [Additional context]
2. [Requirement description] - [Additional context]

**Should Have (P1)** - Important but not blocking:
1. [Requirement description] - [Additional context]

**Nice to Have (P2)** - Future enhancements:
1. [Requirement description] - [Additional context]

#### User Workflows

**Workflow 1: [Workflow Name]**
1. User navigates to [location]
2. User [action]
3. System [response/feedback]
4. User [action]
5. System [final state/result]

**Workflow 2: [Workflow Name]**
1. [Step-by-step user journey]

#### Data Requirements

**Data to Capture** (inputs from users):
| Field Name | Type | Required? | Validation Rules | Notes |
|------------|------|-----------|------------------|-------|
| [field] | [string/number/date] | Yes/No | [min/max/pattern] | [context] |

**Data to Display** (outputs to users):
| Field Name | Source | Format | Conditions |
|------------|--------|--------|------------|
| [field] | [database/API/computed] | [how presented] | [when shown] |

**Data Relationships**:
- [Entity A] belongs to [Entity B]
- [Entity C] has many [Entity D]
- [Entity E] has many [Entity F] through [join table]

---

### 4. Technical Requirements

#### Architecture Considerations

**Affected Layers** (which parts of Clean Architecture):
- [ ] **Domain Layer** - [What business logic? e.g., "validation of discount rules"]
- [ ] **Application Layer** - [What use cases? e.g., "process order with payment"]
- [ ] **Infrastructure Layer** - [What persistence/external services? e.g., "store order in DB, call payment API"]
- [ ] **Interface Layer** - [What UI/endpoints? e.g., "checkout LiveView page"]

**Technology Stack**:
- **Backend**: [What Phoenix/Elixir components? e.g., "Channels for real-time updates"]
- **Frontend**: [What TypeScript/LiveView? e.g., "LiveView hooks for rich text editor"]
- **Real-time**: [EventBus domain events? e.g., "Emit OrderCreated event via EventBus for real-time updates"]
- **Storage**: [What DB changes? e.g., "new orders table, add status to users table"]
- **External Services**: [Any APIs? e.g., "Stripe payment API, SendGrid email"]

#### Integration Points

**Existing Systems**:
| System/Context | Integration Type | Purpose | Notes |
|----------------|------------------|---------|-------|
| [Context name] | [Read/Write/Event] | [Why integrate?] | [Concerns?] |

**External Services**:
| Service | API/SDK | Authentication | Rate Limits | Error Handling |
|---------|---------|----------------|-------------|----------------|
| [Service] | [REST/GraphQL/SDK] | [API key/OAuth] | [Limits] | [How to handle?] |

#### Performance Requirements

- **Response Time**: [Target latency, e.g., "< 200ms for search results"]
- **Throughput**: [Volume, e.g., "handle 100 concurrent users"]
- **Data Volume**: [Scale, e.g., "support 10,000 products"]
- **Real-time Updates**: [Latency, e.g., "updates propagate within 1 second"]

#### Security Requirements

**Authentication**:
- [ ] Requires user login
- [ ] OAuth/SSO integration
- [ ] API token authentication
- [ ] No authentication required

**Authorization**:
- [ ] Role-based access control (specify roles)
- [ ] Owner-only access
- [ ] Team/workspace-based permissions
- [ ] Public access

**Data Privacy**:
- [ ] Contains PII (Personally Identifiable Information)
- [ ] Requires encryption at rest
- [ ] Requires encryption in transit (HTTPS)
- [ ] GDPR/compliance considerations
- [ ] Audit logging required

**Input Validation**:
- [What inputs need sanitization?]
- [What validations prevent security issues?]
- [File upload restrictions?]

---

### 5. Non-Functional Requirements

#### Scalability
- [How should it scale? e.g., "horizontal scaling for background jobs"]

#### Reliability
- [Uptime requirements? e.g., "99.9% availability"]
- [Fault tolerance? e.g., "graceful degradation if external API fails"]

#### Maintainability
- [Code quality standards?]
- [Documentation requirements?]

#### Accessibility
- [WCAG compliance level?]
- [Screen reader support?]
- [Keyboard navigation?]

#### Observability
- [What metrics to track?]
- [What errors to monitor?]
- [Performance monitoring?]

---

### 6. User Interface Requirements

#### User Experience Goals
- [Goal 1: e.g., "minimize clicks to complete action"]
- [Goal 2: e.g., "provide clear feedback at each step"]

#### Key Interactions
- [Interaction pattern 1: e.g., "drag-and-drop file upload"]
- [Interaction pattern 2: e.g., "inline editing with auto-save"]

#### Responsive Design
- [ ] Desktop support required (specify breakpoints)
- [ ] Mobile support required (specify breakpoints)
- [ ] Tablet support required (specify breakpoints)

#### Visual Design Notes
- [Brand guidelines to follow?]
- [Existing component library?]
- [Design mockups available?]

---

### 7. Edge Cases & Error Handling

#### Known Edge Cases

**Edge Case 1**: [Scenario description]
- **Expected Behavior**: [What should happen?]
- **Rationale**: [Why this behavior?]

**Edge Case 2**: [Scenario description]
- **Expected Behavior**: [What should happen?]
- **Rationale**: [Why this behavior?]

#### Error Scenarios

**Error Type 1**: [e.g., "Network timeout"]
- **User-Facing Message**: [Friendly error message]
- **Recovery Action**: [What can user do? e.g., "Retry automatically"]
- **Logging**: [What to log for debugging?]

**Error Type 2**: [e.g., "Invalid input"]
- **User-Facing Message**: [Clear validation message]
- **Recovery Action**: [How to correct?]
- **Prevention**: [Client-side validation?]

#### Boundary Conditions
- Empty state: [What if no data?]
- Maximum limits: [What if too much data?]
- Concurrent access: [What if multiple users act simultaneously?]

---

### 8. Validation & Testing Criteria

#### Acceptance Criteria

- [ ] **AC1**: [Specific, testable criterion] - Verify by: [how to test]
- [ ] **AC2**: [Specific, testable criterion] - Verify by: [how to test]
- [ ] **AC3**: [Specific, testable criterion] - Verify by: [how to test]

#### Test Scenarios

**Happy Path Tests**:
1. **Scenario**: [Normal user flow]
   **Expected Result**: [What should happen]

2. **Scenario**: [Another common case]
   **Expected Result**: [What should happen]

**Edge Case Tests**:
1. **Scenario**: [Boundary condition]
   **Expected Result**: [How to handle]

2. **Scenario**: [Error condition]
   **Expected Result**: [Error handling behavior]

**Security Tests**:
1. **Scenario**: [Unauthorized access attempt]
   **Expected Result**: [Access denied appropriately]

**Performance Tests**:
1. **Scenario**: [Load condition]
   **Expected Result**: [Performance target met]

---

### 9. Dependencies & Assumptions

#### Dependencies

**Internal Dependencies**:
- [Feature/module this depends on] - [Current status] - [Risk if unavailable]

**External Dependencies**:
- [Third-party service/library] - [SLA/reliability] - [Fallback plan if unavailable]

**Data Dependencies**:
- [Required data/schema changes] - [Migration complexity]

#### Assumptions

- **Assumption 1**: [What we're assuming about users/system]
  - **Impact if wrong**: [What happens if assumption is false?]

- **Assumption 2**: [What we're assuming about infrastructure]
  - **Impact if wrong**: [What happens if assumption is false?]

#### Risks

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| [Risk description] | [High/Med/Low] | [High/Med/Low] | [How to mitigate?] |

---

### 10. Success Metrics

#### Key Performance Indicators (KPIs)

- **[Metric Name]**: [Target value] - Measured by: [how tracked]
- **[Metric Name]**: [Target value] - Measured by: [how tracked]

#### User Satisfaction Metrics

- **[Metric]**: [How measured? e.g., "NPS survey after 1 week"]
- **[Metric]**: [How measured? e.g., "task completion rate"]

#### Business Metrics

- **[Metric]**: [Target] - [Why important?]

#### Technical Metrics

- **Performance**: [e.g., "p95 latency < 200ms"]
- **Reliability**: [e.g., "error rate < 0.1%"]
- **Adoption**: [e.g., "80% of users try feature in first month"]

---

### 11. Out of Scope

Explicitly list what this feature will **NOT** include to prevent scope creep:

- ❌ [Feature/capability not included]
- ❌ [Feature/capability not included]
- ❌ [Feature/capability not included]

**Rationale**: [Why these are out of scope - complexity, timeline, etc.]

---

### 12. Future Considerations

Features or enhancements to consider for **future iterations** (not MVP):

- 🔮 [Future enhancement] - [Why deferred?]
- 🔮 [Future enhancement] - [Why deferred?]
- 🔮 [Future enhancement] - [Why deferred?]

---

### 13. Codebase Context

*(Filled in by prd agent after researching codebase)*

#### Existing Patterns

**Similar Features**:
- [Feature name] - Located in: [file path] - Pattern: [approach used]

**Reusable Components**:
- [Component/module] - Located in: [path] - Purpose: [what it does]

#### Affected Boundaries (Phoenix Contexts)

| Context | Why Affected? | Changes Needed | Complexity |
|---------|---------------|----------------|------------|
| [Context name] | [Reason] | [Read/Write/Schema changes] | [Low/Med/High] |

#### Available Infrastructure

**Existing Services/Modules**:
- [Service name] - [Purpose] - Can leverage: [yes/no/partially]

**Database Schema**:
- [Existing tables that will be used/modified]

**Authentication/Authorization**:
- [Existing auth system that can be leveraged]

#### Integration Points

**Features This Connects To**:
- [Feature name] - [File/module] - [Integration type]

**Domain Events / EventBus Topics**:
- [Existing domain events that might be relevant, e.g., "events:workspace:{id}", "ProjectCreated", "DocumentDeleted"]

---

### 14. Open Questions

Questions that need resolution before implementation begins:

- [ ] **Q1**: [Question about requirements/scope]
  - **Blocker?**: [Yes/No]
  - **Owner**: [Who should answer?]

- [ ] **Q2**: [Question about technical feasibility]
  - **Blocker?**: [Yes/No]
  - **Owner**: [Who should answer?]

---

### 15. Approvals & Sign-Off

- [ ] **User/Stakeholder Approval** - [Name/Date]
- [ ] **Technical Feasibility Confirmed** - [Name/Date]
- [ ] **Security Review** (if needed) - [Name/Date]
- [ ] **Ready for Architect Review** - [Name/Date]

---

## Document Metadata

**Document Prepared By**: PRD Agent
**Date Created**: [YYYY-MM-DD]
**Last Updated**: [YYYY-MM-DD]
**Version**: [1.0]
**Status**: [Draft | In Review | Approved | Implementation]

---

## How to Use This Template

### For the PRD Agent

1. **Gather requirements** through structured questioning (AskUserQuestion tool)
2. **Research codebase** using Grep/Glob/Read tools
3. **Fill in each section** with specifics from user responses and research
4. **Flag open questions** that need resolution
5. **Present complete PRD** to user for approval
6. **Hand off to architect** once approved

### For the Architect Agent

1. **Read the PRD** as source of truth for requirements
2. **Focus on sections**:
   - Functional Requirements (what to build)
   - Technical Requirements (constraints)
   - Affected Boundaries (Phoenix contexts)
   - Acceptance Criteria (definition of done)
3. **Translate requirements** into TDD implementation plan
4. **Break down into layers**: Domain → Application → Infrastructure → Interface
5. **Create RED-GREEN-REFACTOR cycles** for each component

### For Implementation Agents (phoenix-tdd, typescript-tdd)

- **Refer to PRD** for context on "why" this feature exists
- **Use acceptance criteria** to guide test writing
- **Check edge cases** section when writing error handling tests
- **Validate against success metrics** to ensure feature meets goals

---

## Example PRD Excerpt

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
1. Send email invitation with unique link - expires in 7 days
2. Allow invitee to accept/decline invitation
3. Automatically grant workspace access on acceptance
4. Show pending invitations in workspace settings

### 4. Technical Requirements

**Affected Layers**:
- [x] Domain Layer - invitation validation, expiry logic
- [x] Application Layer - send invitation use case, accept invitation use case
- [x] Infrastructure Layer - invitations table, email sending
- [x] Interface Layer - invitation form, invitation list view

**Technology Stack**:
- Backend: Ecto schema for invitations, context for invitation management
- Frontend: LiveView form for sending invites, LiveView component for invite list
- Storage: New `workspace_invitations` table

### 8. Validation & Testing Criteria

**Acceptance Criteria**:
- [ ] Owner can send invitation to valid email address
- [ ] Invitee receives email with working link
- [ ] Invitation link expires after 7 days
- [ ] Accepted invitation grants workspace access
- [ ] Owner can see list of pending invitations

---

This template ensures comprehensive requirements gathering while maintaining clear boundaries between "what to build" (PRD) and "how to build it" (architect's implementation plan).
