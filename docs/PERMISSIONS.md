# Permission System

This document describes the comprehensive permission system for workspace members in Jarga.

## Role Hierarchy

The system implements a role-based access control (RBAC) model with four distinct roles:

- **Guest**: Can only view content, no editing, creating or deleting at any level
- **Member**: Can view all, edit and pin shared pages, create their own pages and projects (which they can edit and delete). Cannot edit or delete projects they don't own. Cannot delete pages they don't own. Cannot edit the workspace.
- **Admin**: Can change people's roles (other than owner), manage all projects, and manage shared pages (edit, delete, pin). Can edit the workspace, but not delete it. **Cannot manage non-shared pages.**
- **Owner**: Can do everything including deleting the workspace. **Cannot manage non-public pages they don't own.**

## Permission Matrix

### Workspace Permissions

| Action | Guest | Member | Admin | Owner |
|--------|-------|--------|-------|-------|
| View workspace | ✓ | ✓ | ✓ | ✓ |
| Edit workspace (name, description, etc.) | ✗ | ✗ | ✓ | ✓ |
| Delete workspace | ✗ | ✗ | ✗ | ✓ |
| Manage members (invite, change roles, remove) | ✗ | ✗ | ✓* | ✓* |

\* Cannot change or remove the owner role

### Project Permissions

| Action | Guest | Member | Admin | Owner |
|--------|-------|--------|-------|-------|
| View all projects | ✓ | ✓ | ✓ | ✓ |
| Create project | ✗ | ✓ | ✓ | ✓ |
| Edit own project | ✗ | ✓ | ✓ | ✓ |
| Edit others' project | ✗ | ✗ | ✓ | ✓ |
| Delete own project | ✗ | ✓ | ✓ | ✓ |
| Delete others' project | ✗ | ✗ | ✓ | ✓ |

### Page Permissions

| Action | Guest | Member | Admin | Owner |
|--------|-------|--------|-------|-------|
| View all pages | ✓ | ✓ | ✓ | ✓ |
| Create page | ✗ | ✓ | ✓ | ✓ |
| Edit own page | ✗ | ✓ | ✓ | ✓ |
| Edit shared (public) page | ✗ | ✓ | ✓ | ✗ |
| Edit others' non-shared page | ✗ | ✗ | ✗ | ✗ |
| Delete own page | ✗ | ✓ | ✓ | ✓ |
| Delete shared page | ✗ | ✗ | ✓ | ✗ |
| Delete others' non-shared page | ✗ | ✗ | ✗ | ✗ |
| Pin own page | ✗ | ✓ | ✓ | ✓ |
| Pin shared (public) page | ✗ | ✓ | ✓ | ✓ |
| Pin others' non-shared page | ✗ | ✗ | ✗ | ✗ |

## Key Concepts

### Ownership

- **Projects**: Owned by the user who created them (`user_id` field)
- **Pages**: Owned by the current user (`user_id` field), may differ from creator (`created_by` field)
- **Workspaces**: No explicit owner field; owner is determined by WorkspaceMember record with `role: :owner`

### Shared vs Non-Shared Pages

- **Shared (Public) Pages**: Pages with `is_public: true`
  - Members and admins can edit these pages even if they don't own them
  - Owner cannot edit shared pages they don't own (per requirements)

- **Non-Shared (Private) Pages**: Pages with `is_public: false`
  - Only the owner and admins can edit these pages
  - Members cannot edit private pages they don't own

### Special Rules

1. **Owner role is permanent**: Once assigned, the owner role cannot be changed or removed
2. **Owner cannot manage non-public content of others**: This ensures privacy of individual work
3. **Admin can only manage shared (public) pages**: Can edit, delete, and pin shared pages, but **cannot** manage non-shared pages. Has full control over all projects.
4. **Member has limited creation rights**: Can create their own content and edit shared pages, but cannot manage others' private content
5. **Guest is read-only**: Cannot create, edit, delete, or pin anything

## Implementation

The permission system is implemented in three layers:

### 1. Domain Layer - Permission Policy

**File**: `lib/jarga/workspaces/policies/permissions_policy.ex`

Pure domain logic module that defines permissions:

```elixir
# Check if a role can perform an action
PermissionsPolicy.can?(:member, :edit_page, owns_resource: true, is_public: false)
# => true

PermissionsPolicy.can?(:member, :edit_page, owns_resource: false, is_public: false)
# => false
```

### 2. Application Layer - Use Cases

Use cases will check permissions before executing operations:

```elixir
defmodule UpdatePage do
  def execute(user, workspace_id, page_id, attrs) do
    with {:ok, member} <- get_workspace_member(user, workspace_id),
         {:ok, page} <- get_page(page_id),
         :ok <- authorize_edit(member.role, page, user.id) do
      # Update the page
    end
  end

  defp authorize_edit(role, page, user_id) do
    owns_page = page.user_id == user_id
    can_edit = PermissionsPolicy.can?(role, :edit_page,
      owns_resource: owns_page,
      is_public: page.is_public
    )

    if can_edit, do: :ok, else: {:error, :unauthorized}
  end
end
```

### 3. Interface Layer - LiveView

LiveView components will use permissions to show/hide UI elements:

```elixir
def render(assigns) do
  ~H"""
  <div>
    <%= if can_edit_page?(@current_member, @page, @current_user) do %>
      <button phx-click="edit">Edit</button>
    <% end %>
  </div>
  """
end

defp can_edit_page?(member, page, user) do
  PermissionsPolicy.can?(member.role, :edit_page,
    owns_resource: page.user_id == user.id,
    is_public: page.is_public
  )
end
```

## Testing

The permission system has comprehensive test coverage in:

- `test/jarga/workspaces/policies/permissions_policy_test.exs` - Domain-level permission tests

Each role × action × context combination is tested to ensure correct behavior.

## Examples

### Example 1: Member editing a shared page

```elixir
# User is a member, page is public but owned by someone else
PermissionsPolicy.can?(:member, :edit_page, owns_resource: false, is_public: true)
# => true ✓
```

### Example 2: Owner trying to edit someone's private page

```elixir
# User is the owner, but page is private and owned by another user
PermissionsPolicy.can?(:owner, :edit_page, owns_resource: false, is_public: false)
# => false ✗ (Per requirements: owners cannot manage non-public pages of others)
```

### Example 3: Admin deleting any project

```elixir
# Admin can delete any project regardless of ownership
PermissionsPolicy.can?(:admin, :delete_project, owns_resource: false)
# => true ✓
```

### Example 3b: Admin trying to delete someone's private page

```elixir
# Admin cannot delete private pages (only shared pages)
PermissionsPolicy.can?(:admin, :delete_page, owns_resource: false, is_public: false)
# => false ✗
```

### Example 4: Guest trying to create a page

```elixir
# Guests are read-only
PermissionsPolicy.can?(:guest, :create_page)
# => false ✗
```

## Future Enhancements

Potential improvements to consider:

1. **Granular permissions**: Allow custom permission sets per user
2. **Page-level collaborators**: Specific users who can edit certain pages
3. **Project-level permissions**: Different permissions within a project
4. **Audit logging**: Track who performed what actions
5. **Permission templates**: Reusable permission sets for common scenarios
