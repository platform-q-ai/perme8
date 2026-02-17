# PRD: Workspace Management UI — Invites, Roles & Members

## Summary
- **Problem**: The Identity app is at 90% completion. The workspace management UI (LiveView layer) is the last remaining piece needed to ship workspace management. The domain layer, application layer (use cases), and infrastructure layer are fully built — only the interface layer needs implementation.
- **Value**: Enables users to manage workspace members, invite collaborators by email, assign/change roles, and remove members through an intuitive browser-based UI. This completes the Identity tenancy boundary for the entire Perme8 platform.
- **Users**: Workspace owners, admins, members, and guests. Owners and admins have full management capabilities; members and guests have read-only access to workspace details.

## User Stories

- As a **workspace owner**, I want to create new workspaces so that I can organize my team's work into separate collaboration spaces.
- As a **workspace owner or admin**, I want to edit workspace details (name, description, color) so that workspace information stays current.
- As a **workspace owner**, I want to delete a workspace so that I can clean up unused workspaces.
- As a **workspace owner or admin**, I want to invite people by email so that new collaborators can join my workspace.
- As a **workspace owner or admin**, I want to change a member's role (admin/member/guest) so that I can control access levels.
- As a **workspace owner or admin**, I want to remove a member from a workspace so that I can manage who has access.
- As a **workspace member**, I want to see the list of workspace members and their roles so that I know who I'm collaborating with.
- As a **workspace member**, I want to see pending invitations so that I know who has been invited but hasn't joined yet.
- As a **user**, I want to see all my workspaces listed so that I can navigate between them easily.
- As a **user with no workspaces**, I want to see a helpful empty state with a create action so that I know how to get started.

## Functional Requirements

### Must Have (P0)

1. **Workspace List Page** (`/app/workspaces`)
   - Display all workspaces the user belongs to as a card grid
   - Each card shows workspace name, description, and color indicator
   - "New Workspace" button linked to create page
   - Empty state with helpful message and create CTA when user has no workspaces
   - Cards link to workspace detail page

2. **Workspace Create Page** (`/app/workspaces/new`)
   - Form with name (required), description (optional), and color (optional) fields
   - Client-side validation (name can't be blank)
   - Submit creates workspace and adds creator as owner
   - Success flash and redirect to workspace list
   - Validation errors displayed inline

3. **Workspace Detail/Show Page** (`/app/workspaces/:slug`)
   - Display workspace name, description, projects, documents, and agents
   - Kebab menu (⋮) for owners/admins with: Edit Workspace, Manage Members, Delete Workspace
   - Members/guests see NO kebab menu (no management actions)
   - Owner-only: Delete Workspace with browser confirm dialog
   - Admin/Owner: Edit Workspace link navigates to edit page
   - Admin/Owner: Manage Members opens member management modal

4. **Workspace Edit Page** (`/app/workspaces/:workspace_slug/edit`)
   - Pre-populated form with current workspace details
   - Name, description, color fields
   - Submit updates workspace and redirects back to show page
   - Success/error flash messages
   - Only accessible by admins and owners (authorization enforced)

5. **Members Management Modal** (within workspace show page)
   - Opens from "Manage Members" kebab menu action
   - **Invite Section**: Email input + role select (admin/member/guest) + Invite button
   - **Members List Table** with columns: Member (avatar + email), Role, Status, Joined, Actions
   - Owner's role displayed as a badge (not editable select)
   - Non-owner roles displayed as `<select>` dropdowns for inline role changes
   - Remove button (trash icon) for each non-owner member with browser confirm
   - Status badges: "Active" (green, for joined members) and "Pending" (yellow, for invited)
   - "Done" button to close modal
   - Members list deferred-loaded when modal opens (performance optimization)

6. **Role-Based Access Control in UI**
   - Owner: all actions (create, edit, delete workspace; invite, change role, remove member)
   - Admin: edit workspace, invite member, change role, remove member (NOT delete workspace)
   - Member: view workspace (no management actions, no kebab menu)
   - Guest: view workspace (no management actions, no kebab menu)
   - Non-member: redirected with "Workspace not found" flash

### Should Have (P1)

1. **Real-time Updates via PubSub**
   - Workspace list updates when user is invited to or removed from a workspace
   - Members list updates when a member joins or an invitation is declined
   - Workspace name updates when edited by another user

2. **Invitation Status Tracking**
   - Pending invitations show with "Pending" badge and "Not yet" join date
   - Accepted members show with "Active" badge and formatted join date

### Nice to Have (P2)

1. **Workspace color as a color picker input** (currently text input for hex values)
2. **Bulk member operations** (invite multiple emails at once)
3. **Search/filter within members list** for large workspaces

## User Workflows

### Workspace CRUD

1. User navigates to `/app/workspaces` → System shows workspace card grid
2. User clicks "New Workspace" → System navigates to `/app/workspaces/new`
3. User fills name, description, color → clicks "Create Workspace" → System creates workspace, adds user as owner, redirects to list with success flash
4. Owner/Admin navigates to workspace → clicks kebab → "Edit Workspace" → System navigates to edit page
5. Owner/Admin updates fields → clicks "Update Workspace" → System saves and redirects to show page with success flash
6. Owner navigates to workspace → clicks kebab → "Delete Workspace" → browser confirm → System deletes workspace, redirects to list with success flash

### Member Management

1. Owner/Admin on workspace show → clicks kebab → "Manage Members" → System opens modal with invite form and members list
2. Owner/Admin enters email + selects role → clicks "Invite" → System creates pending invitation, sends email notification, updates members list in modal
3. Owner/Admin changes role via select dropdown → System updates role immediately, shows success flash
4. Owner/Admin clicks remove (trash icon) → browser confirm → System removes member, shows success flash
5. Owner/Admin clicks "Done" → System closes modal

### Access Control

1. Non-member navigates to workspace URL → System redirects to workspace list with "Workspace not found" flash
2. Member/Guest navigates to workspace → System shows workspace content without kebab menu (no management actions)
3. Admin navigates to workspace → System shows kebab with Edit + Manage Members (no Delete)
4. Owner navigates to workspace → System shows kebab with Edit + Manage Members + Delete

## Data Requirements

### Capture
- **Workspace**: `name` (string, required, max 255), `description` (text, optional), `color` (string, optional, hex format)
- **Invitation**: `email` (string, required, valid email), `role` (enum: admin|member|guest)
- **Role Change**: `email` (string, identifies target member), `value` (enum: admin|member|guest)

### Display
- **Workspace Card**: name, description (truncated), color indicator
- **Member Row**: email (with avatar initials), role (badge or select), status (Active/Pending badge), joined date, remove action
- **Invite Form**: email input, role select (Admin/Member/Guest options)

### Relationships
- `Workspace` has many `WorkspaceMember` (via `workspace_id`)
- `WorkspaceMember` belongs to `Workspace` and optionally to `User` (via `user_id`, nil for pending invitations)
- `WorkspaceMember` tracks `invited_by` (foreign key to inviter's user_id)
- `WorkspaceMember` has `role` enum: `:owner | :admin | :member | :guest`
- `WorkspaceMember` has `invited_at` (when invited) and `joined_at` (nil = pending, non-nil = accepted)

## Technical Considerations

### Affected Layers
- **Interface Layer** (primary): LiveView modules in `apps/jarga_web/lib/live/app_live/workspaces/`
- **Domain Layer** (existing, no changes): Entities, Policies already complete
- **Application Layer** (existing, no changes): Use cases already complete
- **Infrastructure Layer** (existing, no changes): Repositories, Queries already complete

### Integration Points
- **Identity Context API** (`Identity` module): All workspace/member operations delegate to Identity
- **Jarga.Workspaces Facade** (`apps/jarga/lib/workspaces.ex`): Thin delegation layer used by jarga_web LiveViews
- **PubSub** (`Jarga.PubSub`): Real-time workspace updates via `workspace:#{workspace_id}` and `user:#{user_id}` topics
- **PermissionsHelper** (`JargaWeb.Live.PermissionsHelper`): Role-based UI conditional rendering
- **DaisyUI Components**: Modal (`modal modal-open`), table (`table table-sm`), badges, kebab menu, card grid

### UI Framework
- **DaisyUI** for component classes (badges, modals, tables, cards, buttons)
- **Heroicons** for icons (via `.icon` component)
- **Phoenix LiveView** for all pages (no traditional controllers for workspace UI)
- **Layouts.admin** layout wrapper used by all workspace LiveViews

### Performance
- Members list loaded on-demand when modal opens (not on page mount)
- PubSub subscriptions for real-time updates
- Single optimized query for workspace + member via `get_workspace_and_member_by_slug`

### Security
- All workspace operations verify membership through `Identity` context API
- Role-based authorization enforced at both UI level (conditional rendering) and backend (use cases check permissions)
- Non-members cannot access workspace pages (redirect with error)
- Owner role is protected: cannot be assigned, changed, or removed via UI
- `String.to_existing_atom/1` used for role conversion to prevent atom table exhaustion

## Edge Cases & Error Handling

1. **Scenario**: User submits workspace create with empty name → **Expected**: Inline validation error "can't be blank", no submission
2. **Scenario**: Admin invites email that's already a member → **Expected**: Flash error "User is already a member of this workspace"
3. **Scenario**: Admin invites with invalid role → **Expected**: Flash error "Invalid role selected"
4. **Scenario**: Admin tries to change owner's role → **Expected**: Owner role displayed as badge (not select), no change possible; use case returns `:cannot_change_owner_role`
5. **Scenario**: Admin tries to remove owner → **Expected**: No remove button shown for owner; use case returns `:cannot_remove_owner`
6. **Scenario**: Non-member navigates to workspace URL → **Expected**: Redirect to `/app/workspaces` with flash "Workspace not found"
7. **Scenario**: Admin navigates to delete workspace → **Expected**: Delete option not shown in kebab menu (only owner can delete)
8. **Scenario**: Member/Guest attempts to access edit page directly → **Expected**: Authorization check, redirect or error
9. **Scenario**: Workspace deleted while another user is viewing it → **Expected**: PubSub notification, graceful handling
10. **Scenario**: Invitation sent to user who later signs up → **Expected**: Pending invitation converted to membership via `accept_pending_invitations`

## Acceptance Criteria

- [ ] Workspace list page (`/app/workspaces`) displays all user workspaces as cards
- [ ] Empty state shown with "No workspaces yet" message and create CTA
- [ ] New Workspace page creates workspace with creator as owner
- [ ] Invalid workspace creation (empty name) shows inline validation errors
- [ ] Workspace show page displays workspace details with projects, documents, agents sections
- [ ] Kebab menu with Edit/Manage Members/Delete shown only for authorized roles
- [ ] Edit page pre-populates form and saves changes with success flash
- [ ] Members modal opens from kebab menu with invite form and members table
- [ ] Invite form sends invitation and refreshes members list
- [ ] Role change via select dropdown updates immediately with success flash
- [ ] Owner role displayed as badge (not editable)
- [ ] Remove member button with confirm dialog removes member and shows flash
- [ ] Owner cannot be removed (no remove button shown)
- [ ] Members/Guests see no kebab menu or management actions
- [ ] Non-members redirected with "Workspace not found" flash
- [ ] Pending invitations show "Pending" status badge
- [ ] Active members show "Active" status badge with join date
- [ ] All 24 existing BDD scenarios pass (7 CRUD + 10 members + 7 navigation)

## Codebase Context

### Existing Patterns (UI already implemented)
- **Workspace Index**: `apps/jarga_web/lib/live/app_live/workspaces/index.ex` — card grid with empty state
- **Workspace New**: `apps/jarga_web/lib/live/app_live/workspaces/new.ex` — form with validation
- **Workspace Edit**: `apps/jarga_web/lib/live/app_live/workspaces/edit.ex` — pre-populated form
- **Workspace Show**: `apps/jarga_web/lib/live/app_live/workspaces/show.ex` — kebab menu, members modal, projects/docs/agents sections
- **Permissions Helper**: `apps/jarga_web/lib/live/permissions_helper.ex` — role-based UI conditionals

### Existing Domain/Application Code (no changes needed)
- **Identity Context API**: `apps/identity/lib/identity.ex` — public facade with all workspace/member operations
- **Jarga.Workspaces Facade**: `apps/jarga/lib/workspaces.ex` — delegation to Identity
- **Domain Entities**: `Workspace`, `WorkspaceMember` — pure structs with business rule methods
- **Domain Policies**: `MembershipPolicy` (invitation/role/removal rules), `WorkspacePermissionsPolicy` (action-role matrix)
- **Use Cases**: `InviteMember`, `ChangeMemberRole`, `RemoveMember` — full orchestration with DI
- **Infrastructure**: `MembershipRepository`, `WorkspaceQueries`, `WorkspaceMemberSchema`

### BDD Scenarios (already written, must pass)
- `apps/jarga_web/test/features/workspaces/crud.browser.feature` — 7 scenarios covering create, edit (admin/member/guest), delete (owner/admin), validation
- `apps/jarga_web/test/features/workspaces/members.browser.feature` — 10 scenarios covering modal open, invite, member/guest restrictions, role change, owner role display, member removal, owner protection, modal close, non-member access
- `apps/jarga_web/test/features/workspaces/navigation.browser.feature` — 7 scenarios covering detail view, guest limitations, member actions, workspace list, card navigation, empty state, new workspace link

### Router Configuration
- Routes defined in `apps/jarga_web/lib/router.ex` under `/app` scope with `:require_authenticated_user` pipeline
- Live session `:app` with `UserAuth` and `NotificationsLive.OnMount` on_mount hooks
- Key routes: `/app/workspaces`, `/app/workspaces/new`, `/app/workspaces/:workspace_slug/edit`, `/app/workspaces/:slug` (show)

### Key UI Selectors (from BDD scenarios)
- Kebab menu: `button[aria-label='Actions menu']`
- Members list table: `#members-list`
- Members modal: `.modal.modal-open`
- Invite form: email input `[name='email']`, role select `[name='role']`
- Role select per member: `select[data-email='${email}']`
- Remove button per member: `button[phx-value-email='${email}']`
- Workspace form fields: `[name='workspace[name]']`, `[name='workspace[description]']`, `[name='workspace[color]']`

## Open Questions

- [ ] (None — feature is fully specced with existing BDD scenarios and domain/application code)

## Out of Scope

- User registration/login flows (already implemented in Identity)
- API key management (already implemented)
- Project/document CRUD within workspaces (already implemented)
- Agent management within workspaces (already implemented)
- Email notification templates for invitations (handled by infrastructure notifiers)
- Workspace archiving (field exists but no UI planned for this iteration)
- Bulk invitation flows
- Workspace settings page as a separate route (management is via modal on show page)
