# ExoBDD Web Test Seed Data
#
# This script populates the database with fixture data required by the
# exo-bdd browser feature files in apps/jarga_web/test/features/.
#
# Run with: MIX_ENV=test mix run --no-start apps/jarga/priv/repo/exo_seeds_web.exs
#
# Uses --no-start to avoid binding to ports already in use by a running server.
# We start only the bare OTP dependencies needed for seeding: repos and PubSub.
#
# The data created here matches the test users and workspaces referenced in the
# jarga_web browser feature files.

IO.puts("[exo-seeds-web] Starting dependencies...")

# Start the minimal OTP dependencies (no Phoenix endpoints)
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:phoenix_pubsub)
Application.ensure_all_started(:bcrypt_elixir)

# Start Ecto repos
{:ok, _} = Identity.Repo.start_link()
{:ok, _} = Jarga.Repo.start_link()
{:ok, _} = Notifications.Repo.start_link()
{:ok, _} = Agents.Repo.start_link()

# Start PubSub (required by context modules that broadcast events)
Application.ensure_all_started(:perme8_events)

alias Identity.Application.Services.PasswordService
alias Identity.Infrastructure.Schemas.{UserSchema, WorkspaceSchema, WorkspaceMemberSchema}
alias Identity.Domain.Entities.{User, Workspace, WorkspaceMember}
alias Jarga.Projects
alias Jarga.Documents
alias Agents

# ---------------------------------------------------------------------------
# Clean up any existing seed data (idempotent re-runs)
# ---------------------------------------------------------------------------

IO.puts("[exo-seeds-web] Cleaning previous seed data...")

# Jarga-owned tables
Ecto.Adapters.SQL.query!(Jarga.Repo, "TRUNCATE document_components CASCADE", [])
Ecto.Adapters.SQL.query!(Jarga.Repo, "TRUNCATE documents CASCADE", [])
Ecto.Adapters.SQL.query!(Jarga.Repo, "TRUNCATE projects CASCADE", [])
# Other app tables (shared database)
Ecto.Adapters.SQL.query!(Notifications.Repo, "TRUNCATE notifications CASCADE", [])
Ecto.Adapters.SQL.query!(Agents.Repo, "TRUNCATE sessions_tasks CASCADE", [])
Ecto.Adapters.SQL.query!(Agents.Repo, "TRUNCATE sessions_project_tickets CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE api_keys CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE chat_messages CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE chat_sessions CASCADE", [])
Ecto.Adapters.SQL.query!(Agents.Repo, "TRUNCATE workspace_agents CASCADE", [])
Ecto.Adapters.SQL.query!(Agents.Repo, "TRUNCATE agents CASCADE", [])
# Identity-owned tables
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE workspace_members CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE workspaces CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE users_tokens CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE users CASCADE", [])

IO.puts("[exo-seeds-web] Seeding exo-bdd web test data...")

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

create_confirmed_user = fn attrs ->
  {:ok, user} =
    attrs
    |> Map.delete(:password)
    |> Identity.register_user()

  password = Map.get(attrs, :password, "hello world!")
  hashed_password = PasswordService.hash_password(password)

  updated_schema =
    user
    |> UserSchema.to_schema()
    |> Ecto.Changeset.change(
      hashed_password: hashed_password,
      confirmed_at: DateTime.utc_now(:second)
    )
    |> Identity.Repo.update!()

  User.from_schema(updated_schema)
end

create_workspace_with_owner = fn owner, attrs ->
  now = DateTime.utc_now() |> DateTime.truncate(:second)

  {:ok, result} =
    Jarga.Repo.transaction(fn ->
      {:ok, ws_schema} =
        %WorkspaceSchema{}
        |> WorkspaceSchema.changeset(%{
          name: attrs[:name],
          slug: attrs[:slug],
          description: attrs[:description],
          color: attrs[:color],
          is_archived: false
        })
        |> Jarga.Repo.insert()

      {:ok, _member_schema} =
        %WorkspaceMemberSchema{}
        |> WorkspaceMemberSchema.changeset(%{
          workspace_id: ws_schema.id,
          user_id: owner.id,
          email: owner.email,
          role: :owner,
          invited_at: now,
          joined_at: now
        })
        |> Jarga.Repo.insert()

      Workspace.from_schema(ws_schema)
    end)

  {:ok, result}
end

add_member_directly = fn workspace_id, user, role ->
  now = DateTime.utc_now() |> DateTime.truncate(:second)

  %WorkspaceMemberSchema{}
  |> WorkspaceMemberSchema.changeset(%{
    workspace_id: workspace_id,
    user_id: user.id,
    email: user.email,
    role: role,
    invited_at: now,
    joined_at: now
  })
  |> Identity.Repo.insert!()
  |> WorkspaceMember.from_schema()
end

# ---------------------------------------------------------------------------
# 1. Create users (matching the feature file Background users)
# ---------------------------------------------------------------------------

alice =
  create_confirmed_user.(%{
    email: "alice@example.com",
    first_name: "Alice",
    last_name: "Tester"
  })

bob =
  create_confirmed_user.(%{
    email: "bob@example.com",
    first_name: "Bob",
    last_name: "Tester"
  })

charlie =
  create_confirmed_user.(%{
    email: "charlie@example.com",
    first_name: "Charlie",
    last_name: "Tester"
  })

diana =
  create_confirmed_user.(%{
    email: "diana@example.com",
    first_name: "Diana",
    last_name: "Tester"
  })

eve =
  create_confirmed_user.(%{
    email: "eve@example.com",
    first_name: "Eve",
    last_name: "Tester"
  })

grace =
  create_confirmed_user.(%{
    email: "grace@example.com",
    first_name: "Grace",
    last_name: "Tester"
  })

frank =
  create_confirmed_user.(%{
    email: "frank@example.com",
    first_name: "Frank",
    last_name: "Tester"
  })

IO.puts("[exo-seeds-web] Created users: alice, bob, charlie, diana, eve, grace, frank")

# ---------------------------------------------------------------------------
# 2. Create workspaces
# ---------------------------------------------------------------------------

{:ok, product_team} =
  create_workspace_with_owner.(
    alice,
    %{
      name: "Product Team",
      slug: "product-team",
      description: "Product team workspace",
      color: "#4A90E2"
    }
  )

{:ok, engineering} =
  create_workspace_with_owner.(
    alice,
    %{
      name: "Engineering",
      slug: "engineering",
      description: "Engineering workspace",
      color: "#10B981"
    }
  )

# Throwaway workspace for deletion test (workspaces/crud.browser.feature)
{:ok, throwaway_ws} =
  create_workspace_with_owner.(
    alice,
    %{
      name: "Throwaway Workspace",
      slug: "throwaway-workspace",
      description: "Workspace created solely for deletion testing",
      color: "#EF4444"
    }
  )

IO.puts("[exo-seeds-web] Created workspaces: product-team, engineering, throwaway-workspace")

# ---------------------------------------------------------------------------
# 3. Add members to workspaces
# ---------------------------------------------------------------------------

add_member_directly.(product_team.id, bob, :admin)
add_member_directly.(product_team.id, charlie, :member)
add_member_directly.(product_team.id, diana, :guest)
add_member_directly.(product_team.id, frank, :member)
# eve is NOT added — she is a non-member

# Create pending invitation for grace (used by notification accept flow)
%WorkspaceMemberSchema{}
|> WorkspaceMemberSchema.changeset(%{
  workspace_id: product_team.id,
  email: grace.email,
  role: :member,
  invited_by: alice.id,
  invited_at: DateTime.utc_now() |> DateTime.truncate(:second)
})
|> Identity.Repo.insert!()

IO.puts(
  "[exo-seeds-web] Added workspace memberships (bob=admin, charlie=member, diana=guest, frank=member)"
)

# ---------------------------------------------------------------------------
# 4. Create projects
# ---------------------------------------------------------------------------

{:ok, q1_launch} =
  Projects.create_project(alice, product_team.id, %{
    name: "Q1 Launch",
    description: "Q1 product launch plan",
    color: "#F59E0B"
  })

{:ok, mobile_app} =
  Projects.create_project(alice, product_team.id, %{
    name: "Mobile App",
    description: "Mobile application project",
    color: "#3B82F6"
  })

# Throwaway project for deletion test (projects/crud.browser.feature)
{:ok, _throwaway_project} =
  Projects.create_project(alice, product_team.id, %{
    name: "Throwaway Project",
    description: "Project created solely for deletion testing",
    color: "#EF4444"
  })

IO.puts("[exo-seeds-web] Created projects: q1-launch, mobile-app, throwaway-project")

# ---------------------------------------------------------------------------
# 5. Create documents
# ---------------------------------------------------------------------------

{:ok, _product_spec} =
  Documents.create_document(alice, product_team.id, %{
    title: "Product Spec",
    content: "Detailed specifications for the product",
    is_public: true
  })

{:ok, _shared_doc} =
  Documents.create_document(bob, product_team.id, %{
    title: "Shared Doc",
    content: "Shared documentation",
    is_public: true
  })

{:ok, _bobs_private_doc} =
  Documents.create_document(bob, product_team.id, %{
    title: "Bobs Private Doc",
    content: "Bob's private notes",
    is_public: false
  })

{:ok, _launch_plan} =
  Documents.create_document(alice, product_team.id, %{
    title: "Launch Plan",
    content: "Detailed launch plan for Q1",
    project_id: q1_launch.id,
    is_public: true
  })

# Documents referenced by documents/crud.browser.feature
{:ok, _draft_roadmap} =
  Documents.create_document(alice, product_team.id, %{
    title: "Draft Roadmap",
    content: "Draft product roadmap for upcoming quarter",
    is_public: false
  })

{:ok, _private_doc} =
  Documents.create_document(alice, product_team.id, %{
    title: "Private Doc",
    content: "Alice's private document for visibility tests",
    is_public: false
  })

{:ok, _public_doc} =
  Documents.create_document(alice, product_team.id, %{
    title: "Public Doc",
    content: "A public document for visibility and access tests",
    is_public: true
  })

{:ok, _valid_title} =
  Documents.create_document(alice, product_team.id, %{
    title: "Valid Title",
    content: "Document used for empty-title validation test",
    is_public: false
  })

{:ok, _important_doc} =
  Documents.create_document(alice, product_team.id, %{
    title: "Important Doc",
    content: "An unpinned document for pinning tests (crud)",
    is_public: false
  })

{:ok, _collab_pin_doc} =
  Documents.create_document(alice, product_team.id, %{
    title: "Collab Pin Doc",
    content: "An unpinned document for collaboration pin tests",
    is_public: false
  })

{:ok, pinned_doc} =
  Documents.create_document(alice, product_team.id, %{
    title: "Pinned Doc",
    content: "A pinned document for unpinning tests",
    is_public: false
  })

# Pin the document so it appears as pinned in listing tests
{:ok, _} = Documents.update_document(alice, pinned_doc.id, %{is_pinned: true})

{:ok, _old_doc} =
  Documents.create_document(alice, product_team.id, %{
    title: "Old Doc",
    content: "An old document for deletion tests",
    is_public: false
  })

# Documents referenced by documents/access.browser.feature
{:ok, _private_notes} =
  Documents.create_document(alice, product_team.id, %{
    title: "Private Notes",
    content: "Alice's private notes",
    is_public: false
  })

{:ok, _alices_private_notes} =
  Documents.create_document(alice, product_team.id, %{
    title: "Alices Private Notes",
    content: "Alice's private notes for access control tests",
    is_public: false
  })

{:ok, _team_guidelines} =
  Documents.create_document(alice, product_team.id, %{
    title: "Team Guidelines",
    content: "Guidelines for the product team",
    is_public: true
  })

{:ok, _private_roadmap} =
  Documents.create_document(alice, product_team.id, %{
    title: "Private Roadmap",
    content: "Private roadmap document",
    is_public: false
  })

{:ok, _specs} =
  Documents.create_document(alice, product_team.id, %{
    title: "Specs",
    content: "Mobile app specifications",
    project_id: mobile_app.id,
    is_public: true
  })

IO.puts(
  "[exo-seeds-web] Created documents: product-spec, shared-doc, bobs-private-doc, launch-plan, " <>
    "draft-roadmap, private-doc, public-doc, valid-title, important-doc, collab-pin-doc, " <>
    "pinned-doc, old-doc, private-notes, alices-private-notes, team-guidelines, " <>
    "private-roadmap, specs"
)

# ---------------------------------------------------------------------------
# 6. Create agents
# ---------------------------------------------------------------------------

{:ok, code_helper} =
  Agents.create_user_agent(%{
    user_id: alice.id,
    name: "Code Helper",
    description: "Helps with code review and best practices",
    system_prompt: "You are an expert code reviewer. Help with code quality.",
    model: "gpt-4o",
    temperature: 0.7,
    visibility: "SHARED",
    enabled: true
  })

{:ok, _doc_writer} =
  Agents.create_user_agent(%{
    user_id: alice.id,
    name: "Doc Writer",
    description: "Assists with documentation writing",
    system_prompt: "You are a technical writer. Help create clear documentation.",
    model: "gpt-4o",
    temperature: 0.5,
    visibility: "SHARED",
    enabled: true
  })

# Add agent to workspace directly via repository (avoids full context dependencies in seed)
alias Agents.Infrastructure.Repositories.WorkspaceAgentRepository
{:ok, _} = WorkspaceAgentRepository.add_to_workspace(product_team.id, code_helper.id)

IO.puts("[exo-seeds-web] Created agents: code-helper, doc-writer")

# ---------------------------------------------------------------------------
# 7. Create session tasks (for sessions browser tests)
# ---------------------------------------------------------------------------

alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

{:ok, _completed_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Write unit tests for auth",
    status: "completed"
  })
  |> Jarga.Repo.insert()

{:ok, _failed_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Refactor database queries",
    status: "failed"
  })
  |> Jarga.Repo.insert()

{:ok, _cancelled_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Add API endpoint for users",
    status: "cancelled"
  })
  |> Jarga.Repo.insert()

# Long instruction for truncation test (120+ chars)
long_instruction =
  "This is a very long instruction that should be truncated in the task history table to keep the UI clean and this part should not be visible in the table row"

{:ok, _long_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: long_instruction,
    status: "completed"
  })
  |> Jarga.Repo.insert()

IO.puts("[exo-seeds-web] Created session tasks for alice")

# ---------------------------------------------------------------------------
# 7b. Create session tasks with todo items (for todo-progress-bar browser tests)
# ---------------------------------------------------------------------------
# Each group of tasks shares a container_id so they appear as a "session".
# The first task's instruction (by inserted_at ASC) becomes the session title,
# which is slugified in the template to produce the data-testid value.
# The todo_items field stores the persisted todo state as a map with an "items" key.

# Helper to build the todo_items map from a list of {title, status} tuples
build_todo_items = fn items ->
  %{
    "items" =>
      items
      |> Enum.with_index()
      |> Enum.map(fn {{title, status}, index} ->
        %{
          "id" => Ecto.UUID.generate(),
          "title" => title,
          "status" => status,
          "position" => index
        }
      end)
  }
end

# Session: "Todo Initial" — 4 steps, all pending
todo_initial_container = "todo-initial-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, todo_initial_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Todo Initial",
    status: "running",
    container_id: todo_initial_container
  })
  |> Jarga.Repo.insert()

todo_initial_task
|> TaskSchema.status_changeset(%{
  todo_items:
    build_todo_items.([
      {"Plan architecture", "pending"},
      {"Implement feature", "pending"},
      {"Write tests", "pending"},
      {"Deploy changes", "pending"}
    ])
})
|> Jarga.Repo.update!()

IO.puts("[exo-seeds-web] Created todo-initial session")

# Session: "Todo 3 of 7 Complete" — 7 steps, 3 completed, rest pending
todo_partial_container = "todo-partial-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, todo_partial_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Todo 3 of 7 Complete",
    status: "running",
    container_id: todo_partial_container
  })
  |> Jarga.Repo.insert()

todo_partial_task
|> TaskSchema.status_changeset(%{
  todo_items:
    build_todo_items.([
      {"Gather requirements", "completed"},
      {"Design schema", "completed"},
      {"Create migration", "completed"},
      {"Build context", "pending"},
      {"Add LiveView", "pending"},
      {"Write tests", "pending"},
      {"Deploy", "pending"}
    ])
})
|> Jarga.Repo.update!()

IO.puts("[exo-seeds-web] Created todo-3-of-7-complete session")

# Session: "Todo With Failed Step" — 4 steps with mixed statuses including failure
todo_failed_container = "todo-failed-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, todo_failed_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Todo With Failed Step",
    status: "running",
    container_id: todo_failed_container
  })
  |> Jarga.Repo.insert()

todo_failed_task
|> TaskSchema.status_changeset(%{
  todo_items:
    build_todo_items.([
      {"Setup environment", "completed"},
      {"Run migrations", "in_progress"},
      {"Deploy to staging", "failed"},
      {"Verify deployment", "pending"}
    ])
})
|> Jarga.Repo.update!()

IO.puts("[exo-seeds-web] Created todo-with-failed-step session")

# Session: "No Todo" — active session with no todo items
no_todo_container = "no-todo-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, _no_todo_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "No Todo",
    status: "completed",
    container_id: no_todo_container
  })
  |> Jarga.Repo.insert()

IO.puts("[exo-seeds-web] Created no-todo session")

# Session: "Todo Session Completed" — completed session with final todo state
todo_completed_container = "todo-completed-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, todo_completed_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Todo Session Completed",
    status: "completed",
    container_id: todo_completed_container
  })
  |> Jarga.Repo.insert()

todo_completed_task
|> TaskSchema.status_changeset(%{
  todo_items:
    build_todo_items.([
      {"Analyze requirements", "completed"},
      {"Implement solution", "completed"},
      {"Run test suite", "completed"},
      {"Update documentation", "completed"},
      {"Create PR", "completed"}
    ])
})
|> Jarga.Repo.update!()

IO.puts("[exo-seeds-web] Created todo-session-completed session")

IO.puts("[exo-seeds-web] Created all todo progress bar fixture sessions")

# ---------------------------------------------------------------------------
# 7c. Create session tasks with duration and file stats
#     (for session-card-stats browser tests)
# ---------------------------------------------------------------------------

# Session: "Completed With Duration" — completed session with started_at/completed_at (5m apart)
completed_dur_container = "completed-dur-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, completed_dur_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Completed With Duration",
    status: "completed",
    container_id: completed_dur_container
  })
  |> Jarga.Repo.insert()

five_min_ago = DateTime.add(DateTime.utc_now(), -300, :second) |> DateTime.truncate(:second)
just_now = DateTime.utc_now() |> DateTime.truncate(:second)

completed_dur_task
|> TaskSchema.status_changeset(%{
  started_at: five_min_ago,
  completed_at: just_now
})
|> Jarga.Repo.update!()

IO.puts("[exo-seeds-web] Created completed-with-duration session")

# Session: "Failed With Duration" — failed session with started_at/completed_at
failed_dur_container = "failed-dur-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, failed_dur_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Failed With Duration",
    status: "failed",
    container_id: failed_dur_container
  })
  |> Jarga.Repo.insert()

three_min_ago = DateTime.add(DateTime.utc_now(), -180, :second) |> DateTime.truncate(:second)

failed_dur_task
|> TaskSchema.status_changeset(%{
  started_at: three_min_ago,
  completed_at: just_now
})
|> Jarga.Repo.update!()

IO.puts("[exo-seeds-web] Created failed-with-duration session")

# Session: "Pending No Duration" — pending session with no started_at
pending_no_dur_container = "pending-no-dur-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, _pending_no_dur_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Pending No Duration",
    status: "pending",
    container_id: pending_no_dur_container
  })
  |> Jarga.Repo.insert()

IO.puts("[exo-seeds-web] Created pending-no-duration session")

# Session: "Completed With File Stats" — completed session with session_summary + duration
file_stats_container = "file-stats-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, file_stats_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "Completed With File Stats",
    status: "completed",
    container_id: file_stats_container
  })
  |> Jarga.Repo.insert()

file_stats_task
|> TaskSchema.status_changeset(%{
  started_at: five_min_ago,
  completed_at: just_now,
  session_summary: %{"files" => 3, "additions" => 42, "deletions" => 18}
})
|> Jarga.Repo.update!()

IO.puts("[exo-seeds-web] Created completed-with-file-stats session")

# Session: "No File Stats" — completed session with no session_summary
no_file_stats_container = "no-file-stats-#{Ecto.UUID.generate() |> String.slice(0..7)}"

{:ok, _no_file_stats_task} =
  %TaskSchema{}
  |> TaskSchema.changeset(%{
    user_id: alice.id,
    instruction: "No File Stats",
    status: "completed",
    container_id: no_file_stats_container
  })
  |> Jarga.Repo.insert()

IO.puts("[exo-seeds-web] Created no-file-stats session")

IO.puts("[exo-seeds-web] Created all session-card-stats fixture sessions")

# ---------------------------------------------------------------------------
# 8. Create project tickets (for ticket-sync browser tests)
# ---------------------------------------------------------------------------

alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

%ProjectTicketSchema{}
|> ProjectTicketSchema.changeset(%{
  number: 101,
  title: "Implement user authentication",
  body: "Add login and registration flows",
  status: "Ready",
  priority: "Need",
  size: "M",
  labels: ["feature"],
  position: 1,
  created_at: DateTime.utc_now() |> DateTime.truncate(:second),
  sync_state: "synced",
  last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
})
|> Jarga.Repo.insert!()

%ProjectTicketSchema{}
|> ProjectTicketSchema.changeset(%{
  number: 102,
  title: "Fix dashboard layout",
  body: "Sidebar overlaps content on mobile",
  status: "Backlog",
  priority: "Want",
  size: "S",
  labels: ["bug"],
  position: 2,
  created_at: DateTime.utc_now() |> DateTime.truncate(:second),
  sync_state: "synced",
  last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
})
|> Jarga.Repo.insert!()

IO.puts("[exo-seeds-web] Created 2 project tickets for ticket-sync tests")

# ---------------------------------------------------------------------------
# 9. Create notifications (for notifications browser tests)
# ---------------------------------------------------------------------------

alias Notifications.Infrastructure.Schemas.NotificationSchema

# Charlie (member) gets 3 unread notifications
for i <- 1..3 do
  NotificationSchema.create_changeset(%{
    user_id: charlie.id,
    type: "workspace_invitation",
    title: "Workspace Invitation #{i}",
    body: "You have been invited to join Workspace #{i}",
    data: %{"workspace_id" => Ecto.UUID.generate(), "workspace_name" => "Workspace #{i}"}
  })
  |> Notifications.Repo.insert!()
end

IO.puts("[exo-seeds-web] Created 3 unread notifications for charlie")

# Alice (owner) gets 100+ unread notifications (for "99+" badge test)
for i <- 1..105 do
  NotificationSchema.create_changeset(%{
    user_id: alice.id,
    type: "workspace_invitation",
    title: "Invitation #{i}",
    body: "You have been invited to join Team #{i}",
    data: %{"workspace_id" => Ecto.UUID.generate(), "workspace_name" => "Team #{i}"}
  })
  |> Notifications.Repo.insert!()
end

IO.puts("[exo-seeds-web] Created 105 unread notifications for alice (99+ badge test)")

# Grace (invite-only user) gets a workspace invitation notification for accept/decline tests
# Use the actual product_team workspace ID so accept_invitation works
NotificationSchema.create_changeset(%{
  user_id: grace.id,
  type: "workspace_invitation",
  title: "Join Product Team",
  body: "Alice invited you to join Product Team",
  data: %{"workspace_id" => product_team.id, "workspace_name" => "Product Team"}
})
|> Notifications.Repo.insert!()

IO.puts("[exo-seeds-web] Created workspace invitation notification for grace")

# Diana (guest) gets 2 unread notifications (for user-scoping test: different from charlie)
for i <- 1..2 do
  NotificationSchema.create_changeset(%{
    user_id: diana.id,
    type: "workspace_invitation",
    title: "Guest Notification #{i}",
    body: "Notification for guest user #{i}",
    data: %{"workspace_id" => Ecto.UUID.generate(), "workspace_name" => "Team #{i}"}
  })
  |> Notifications.Repo.insert!()
end

IO.puts("[exo-seeds-web] Created 2 unread notifications for diana")

IO.puts("[exo-seeds-web] Done!")
