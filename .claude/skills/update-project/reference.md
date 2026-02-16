# Perme8 Project Reference

All IDs for the **Perme8** GitHub Project V2 (`platform-q-ai/projects/7`).

## Project ID

```
PVT_kwDOAY59zs4BPTB1
```

## Repository

```
Owner: platform-q-ai
Repo:  perme8
Repo ID: R_kgDOQ5pygw
```

## Organisation Members

| Login         | Node ID                  |
|---------------|--------------------------|
| krisquigley   | MDQ6VXNlcjU1MDIyMTU=    |
| quigles1977   | MDQ6VXNlcjM3MDUyOTM0    |

## Field IDs and Options

### Status (Single Select)

**Field ID:** `PVTSSF_lADOAY59zs4BPTB1zg9vwck`

| Status       | Option ID  |
|-------------|------------|
| Backlog     | f75ad846   |
| Ready       | e18bf179   |
| In progress | 47fc9ee4   |
| In review   | aba860b9   |
| Done        | 98236657   |

### Priority (Single Select)

**Field ID:** `PVTSSF_lADOAY59zs4BPTB1zg9vwdw`

| Priority      | Option ID  |
|--------------|------------|
| Need         | 79628723   |
| Want         | 0a877460   |
| Nice to have | da944a9c   |

### Size (Single Select)

**Field ID:** `PVTSSF_lADOAY59zs4BPTB1zg9vwd0`

| Size | Option ID  |
|------|------------|
| XS   | 911790be   |
| S    | b277fb01   |
| M    | 86db8eb3   |
| L    | 853c8207   |
| XL   | 2d0801e2   |

### Iteration

**Field ID:** `PVTIF_lADOAY59zs4BPTB1zg9vwd8`

| Iteration   | ID       | Start Date  | Duration |
|-------------|----------|-------------|----------|
| Iteration 1 | 381c7c80 | 2026-02-15  | 14 days  |
| Iteration 2 | 54cf5c95 | 2026-03-01  | 14 days  |
| Iteration 3 | d2c335bc | 2026-03-15  | 14 days  |
| Iteration 4 | b6a8f1bb | 2026-03-29  | 14 days  |
| Iteration 5 | 955c1297 | 2026-04-12  | 14 days  |

### App/Tool (Single Select)

**Field ID:** `PVTSSF_lADOAY59zs4BPTB1zg9vxpk`

| App/Tool           | Option ID  |
|-------------------|------------|
| Exo BDD           | 060d939c   |
| Perme8            | d985bdfd   |
| Jarga             | 797c37eb   |
| Identify          | 6fb68ea3   |
| Alkali            | 4d44883a   |
| Notifications     | 7ec8467e   |
| Chat              | 0818635b   |
| Agents            | 66043a2c   |
| Composable UI     | 67c1a6e6   |
| Orchestration Flow| 1adbcbae   |
| ERM               | 3ea56897   |

## Label-to-App/Tool Mapping

When creating an issue, the GitHub label should match the App/Tool project field:

| Label          | App/Tool           |
|----------------|--------------------|
| exo-bdd        | Exo BDD            |
| perme8         | Perme8             |
| jarga          | Jarga              |
| identity       | Identify           |
| alkali         | Alkali             |
| notifications  | Notifications      |
| chat           | Chat               |
| agents         | Agents             |
| composable-ui  | Composable UI      |
| orchestration  | Orchestration Flow |
| erm            | ERM                |

## Other Labels (no App/Tool mapping)

These labels can be added alongside an app label:

- `bug`
- `enhancement`
- `documentation`
- `good first issue`
- `help wanted`
- `duplicate`
- `invalid`
- `question`
- `wontfix`

## Read-Only Fields (auto-populated)

These fields are managed by GitHub automatically and should NOT be set manually:

| Field                 | Field ID                                    |
|-----------------------|---------------------------------------------|
| Title                 | PVTF_lADOAY59zs4BPTB1zg9vwcc               |
| Assignees             | PVTF_lADOAY59zs4BPTB1zg9vwcg               |
| Labels                | PVTF_lADOAY59zs4BPTB1zg9vwco               |
| Linked pull requests  | PVTF_lADOAY59zs4BPTB1zg9vwcs               |
| Milestone             | PVTF_lADOAY59zs4BPTB1zg9vwcw               |
| Repository            | PVTF_lADOAY59zs4BPTB1zg9vwc0               |
| Reviewers             | PVTF_lADOAY59zs4BPTB1zg9vwc8               |
| Parent issue          | PVTF_lADOAY59zs4BPTB1zg9vwdA               |
| Sub-issues progress   | PVTF_lADOAY59zs4BPTB1zg9vwdE               |

## Complete Create-Issue Workflow

Here is the full sequence of `gh api` calls to create a fully-populated issue:

### Step 1: Create the issue

```bash
gh issue create --repo platform-q-ai/perme8 \
  --title "feat: example feature" \
  --body "Description here" \
  --label "perme8" \
  --assignee "krisquigley"
```

Capture the issue number from the output URL.

### Step 2: Get the issue's node ID

```bash
gh api graphql -f query='
{
  repository(owner: "platform-q-ai", name: "perme8") {
    issue(number: ISSUE_NUMBER) {
      id
    }
  }
}'
```

### Step 3: Add issue to the project

```bash
gh api graphql -f query='
mutation {
  addProjectV2ItemById(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    contentId: "ISSUE_NODE_ID"
  }) {
    item { id }
  }
}'
```

Capture the `item.id` (project item ID) from the response.

### Step 4: Set Status

```bash
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    itemId: "PROJECT_ITEM_ID"
    fieldId: "PVTSSF_lADOAY59zs4BPTB1zg9vwck"
    value: { singleSelectOptionId: "f75ad846" }
  }) {
    projectV2Item { id }
  }
}'
```

### Step 5: Set Priority

```bash
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    itemId: "PROJECT_ITEM_ID"
    fieldId: "PVTSSF_lADOAY59zs4BPTB1zg9vwdw"
    value: { singleSelectOptionId: "79628723" }
  }) {
    projectV2Item { id }
  }
}'
```

### Step 6: Set Size

```bash
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    itemId: "PROJECT_ITEM_ID"
    fieldId: "PVTSSF_lADOAY59zs4BPTB1zg9vwd0"
    value: { singleSelectOptionId: "86db8eb3" }
  }) {
    projectV2Item { id }
  }
}'
```

### Step 7: Set Iteration

```bash
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    itemId: "PROJECT_ITEM_ID"
    fieldId: "PVTIF_lADOAY59zs4BPTB1zg9vwd8"
    value: { iterationId: "381c7c80" }
  }) {
    projectV2Item { id }
  }
}'
```

### Step 8: Set App/Tool

```bash
gh api graphql -f query='
mutation {
  updateProjectV2ItemFieldValue(input: {
    projectId: "PVT_kwDOAY59zs4BPTB1"
    itemId: "PROJECT_ITEM_ID"
    fieldId: "PVTSSF_lADOAY59zs4BPTB1zg9vxpk"
    value: { singleSelectOptionId: "d985bdfd" }
  }) {
    projectV2Item { id }
  }
}'
```

### Step 9 (Optional): Set parent issue

```bash
gh api graphql -f query='
mutation {
  addSubIssue(input: {
    issueId: "PARENT_ISSUE_NODE_ID"
    subIssueId: "THIS_ISSUE_NODE_ID"
  }) {
    issue { id title }
    subIssue { id title }
  }
}'
```

## Views

| View                | Number | ID                                  |
|---------------------|--------|-------------------------------------|
| Current iteration   | 1      | PVTV_lADOAY59zs4BPTB1zgJW2l0       |
| Next iteration      | 2      | PVTV_lADOAY59zs4BPTB1zgJW2l8       |
| Prioritized backlog | 3      | PVTV_lADOAY59zs4BPTB1zgJW2mA       |
| Roadmap             | 4      | PVTV_lADOAY59zs4BPTB1zgJW2mE       |
| In review           | 5      | PVTV_lADOAY59zs4BPTB1zgJW2mI       |
| My items            | 6      | PVTV_lADOAY59zs4BPTB1zgJW2mM       |
| Task List           | 7      | PVTV_lADOAY59zs4BPTB1zgJW3Eg       |
