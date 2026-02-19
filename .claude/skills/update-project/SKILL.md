---
name: update-project
description: Creates, updates, and manages issues on the Perme8 GitHub Project board (platform-q-ai/projects/7). Use when creating tickets, updating issue status, assigning iterations, setting priority/size, or managing parent/sub-issue relationships.
argument-hint: "[action] [details]"
allowed-tools: Bash(gh *)
---

# Perme8 GitHub Project Manager

Manage issues and project board fields for the **Perme8** GitHub Project V2 (`platform-q-ai/projects/7`).

For complete field IDs, option mappings, and mutation templates, see [reference.md](reference.md).

## Authentication

All `gh` commands MUST run as `perme8[bot]`. Set the token before every operation:

```bash
export GH_TOKEN=$(~/.config/perme8/get-token)
```

The token is short-lived (9 minutes). Re-generate if a command fails with a 401.

## Core Principles

1. **All project fields must be populated** when creating issues: Status, Priority, Size, Iteration, and App/Tool.
2. **Labels must match the App/Tool** value (see label mapping in reference.md).
3. **Parent/sub-issue relationships** must be set when creating sub-tasks.
4. **Always use `gh api graphql`** for project field updates (REST API cannot set ProjectV2 fields).

## Supported Actions

### Create an Issue

When asked to create a ticket/issue:

1. **Create the issue** in the `platform-q-ai/perme8` repository using `gh issue create`
2. **Add the issue to the project** using the `addProjectV2ItemById` mutation
3. **Set ALL project fields** using `updateProjectV2ItemFieldValue` mutations:
   - **Status** (default: `Backlog` unless specified)
   - **Priority** (`Need`, `Want`, or `Nice to have`)
   - **Size** (`XS`, `S`, `M`, `L`, or `XL`)
   - **Iteration** (assign to appropriate iteration)
   - **App/Tool** (which application area this belongs to)
4. **Set parent issue** if this is a sub-task using `addSubIssue`
5. **Assign** to a user if specified

**Example: Create issue and set all fields**

```bash
# Step 1: Create the issue
gh issue create --repo platform-q-ai/perme8 \
  --title "feat: implement user session tracking" \
  --body "Description of the feature..." \
  --label "identity"

# Step 2: Get the issue node ID
gh api graphql -f query='
{
  repository(owner: "platform-q-ai", name: "perme8") {
    issue(number: ISSUE_NUMBER) {
      id
    }
  }
}'

# Step 3: Add to project
gh api graphql -f query='
mutation {
  addProjectV2ItemById(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    contentId: "ISSUE_NODE_ID"
  }) {
    item { id }
  }
}'

# Step 4: Set each field (Status, Priority, Size, Iteration, App/Tool)
# Use the updateProjectV2ItemFieldValue mutation for each field.
# See reference.md for all field IDs and option IDs.
```

### Update Issue Fields

When asked to update a ticket's status, priority, size, iteration, or app/tool:

1. **Find the project item ID** for the issue
2. **Update the field** using `updateProjectV2ItemFieldValue`

```bash
# Find project item ID from issue number
gh api graphql -f query='
{
  repository(owner: "platform-q-ai", name: "perme8") {
    issue(number: ISSUE_NUMBER) {
      projectItems(first: 5) {
        nodes {
          id
          project { title }
        }
      }
    }
  }
}'

# Update a single-select field (Status, Priority, Size, App/Tool)
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    itemId: "PROJECT_ITEM_ID"
    fieldId: "FIELD_ID"
    value: { singleSelectOptionId: "OPTION_ID" }
  }) {
    projectV2Item { id }
  }
}'

# Update an iteration field
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    itemId: "PROJECT_ITEM_ID"
    fieldId: "PVTIF_lADOAY59zs4BPTB1zg9vwd8"
    value: { iterationId: "ITERATION_ID" }
  }) {
    projectV2Item { id }
  }
}'
```

### Move Issue Status

When asked to move a ticket across the board:

```bash
# Update status field
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    itemId: "PROJECT_ITEM_ID"
    fieldId: "PVTSSF_lADOAY59zs4BPTB1zg9vwck"
    value: { singleSelectOptionId: "STATUS_OPTION_ID" }
  }) {
    projectV2Item { id }
  }
}'
```

### Manage Parent/Sub-Issue Relationships

When creating a sub-task or linking issues:

```bash
# Add a sub-issue to a parent
gh api graphql -f query='
mutation {
  addSubIssue(input: {
    issueId: "PARENT_ISSUE_NODE_ID"
    subIssueId: "CHILD_ISSUE_NODE_ID"
  }) {
    issue { id title }
    subIssue { id title }
  }
}'

# Remove a sub-issue from a parent
gh api graphql -f query='
mutation {
  removeSubIssue(input: {
    issueId: "PARENT_ISSUE_NODE_ID"
    subIssueId: "CHILD_ISSUE_NODE_ID"
  }) {
    issue { id title }
    subIssue { id title }
  }
}'
```

### Assign an Issue

```bash
gh issue edit ISSUE_NUMBER --repo platform-q-ai/perme8 --add-assignee USERNAME
```

### List/Query Project Items

```bash
# List items with all field values
gh api graphql -f query='
{
  organization(login: "platform-q-ai") {
    projectV2(number: 7) {
      items(first: 50) {
        nodes {
          content {
            ... on Issue {
              title
              number
              state
              labels(first: 5) { nodes { name } }
              assignees(first: 3) { nodes { login } }
            }
          }
          fieldValues(first: 15) {
            nodes {
              ... on ProjectV2ItemFieldSingleSelectValue {
                name
                field { ... on ProjectV2SingleSelectField { name } }
              }
              ... on ProjectV2ItemFieldIterationValue {
                title
                field { ... on ProjectV2IterationField { name } }
              }
            }
          }
        }
      }
    }
  }
}'
```

## Workflow Checklist

When creating an issue, confirm all of these are set:

- [ ] Title follows convention: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:` prefix
- [ ] Body includes clear description
- [ ] Label matches the App/Tool area
- [ ] Added to project board
- [ ] Status set (default: Backlog)
- [ ] Priority set (Need / Want / Nice to have)
- [ ] Size set (XS / S / M / L / XL)
- [ ] Iteration assigned
- [ ] App/Tool set
- [ ] Parent issue linked (if this is a sub-task)
- [ ] Assignee set (if specified)
