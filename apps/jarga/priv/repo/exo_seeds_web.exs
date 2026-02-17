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

# Start PubSub (required by context modules that broadcast events)
{:ok, _} = Phoenix.PubSub.Supervisor.start_link(name: Jarga.PubSub)

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

Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE api_keys CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE chat_messages CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE chat_sessions CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE workspace_agents CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE agents CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE document_components CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE documents CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE projects CASCADE", [])
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

IO.puts("[exo-seeds-web] Created users: alice, bob, charlie, diana, eve")

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

IO.puts("[exo-seeds-web] Created workspaces: product-team, engineering")

# ---------------------------------------------------------------------------
# 3. Add members to workspaces
# ---------------------------------------------------------------------------

add_member_directly.(product_team.id, bob, :admin)
add_member_directly.(product_team.id, charlie, :member)
add_member_directly.(product_team.id, diana, :guest)
# eve is NOT added — she is a non-member

IO.puts("[exo-seeds-web] Added workspace memberships (bob=admin, charlie=member, diana=guest)")

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

IO.puts("[exo-seeds-web] Created projects: q1-launch, mobile-app")

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

IO.puts("[exo-seeds-web] Done!")
