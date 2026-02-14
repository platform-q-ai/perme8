# ExoBDD Test Seed Data
#
# This script populates the database with fixture data required by the
# exo-bdd feature files in apps/jarga_api/test/features/.
#
# Run with: MIX_ENV=test mix run --no-start apps/jarga/priv/repo/exo_seeds.exs
#
# Uses --no-start to avoid binding to ports already in use by a running server.
# We start only the bare OTP dependencies needed for seeding: repos and PubSub.
#
# The data created here matches the "Assumes:" comments in the feature files.

IO.puts("[exo-seeds] Starting dependencies...")

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

alias Identity.Application.Services.{ApiKeyTokenService, PasswordService}
alias Identity.Infrastructure.Schemas.{ApiKeySchema, UserSchema}
alias Jarga.Workspaces.Infrastructure.Schemas.{WorkspaceMemberSchema}
alias Jarga.Workspaces.Domain.Entities.WorkspaceMember
alias Jarga.Projects
alias Jarga.Documents

# ---------------------------------------------------------------------------
# Deterministic workspace UUIDs for exo-bdd tests.
# These allow feature files (especially ERM which uses UUID-based routing)
# to reference workspace IDs as config variables.
# ---------------------------------------------------------------------------
deterministic_workspace_ids = %{
  "product-team" => "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeee01",
  "engineering" => "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeee02"
}

# ---------------------------------------------------------------------------
# Deterministic API key tokens for exo-bdd tests.
# These are hardcoded plaintext tokens that will be hashed before storage.
# The exo-bdd config maps variable names to these exact strings.
# ---------------------------------------------------------------------------
deterministic_tokens = %{
  "valid-doc-key-product-team" => "exo_test_doc_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "valid-read-key-product-team" =>
    "exo_test_read_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "valid-key-engineering-only" =>
    "exo_test_eng_key_only_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "revoked-key-product-team" => "exo_test_revoked_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "valid-guest-key-product-team" =>
    "exo_test_guest_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "valid-member-key-product-team" =>
    "exo_test_member_key_product_team_aaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "valid-multi-workspace-key" => "exo_test_multi_workspace_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "valid-no-access-key" => "exo_test_no_access_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "valid-phantom-workspace-key" => "exo_test_phantom_workspace_key_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
}

# ---------------------------------------------------------------------------
# Clean up any existing seed data (idempotent re-runs)
# ---------------------------------------------------------------------------

IO.puts("[exo-seeds] Cleaning previous seed data...")

# Truncate in dependency order (children first, then parents).
# NOTE: Identity.Repo and Jarga.Repo share the same underlying Postgres database,
# so we can truncate all tables through a single repo connection. If the repos are
# ever split into separate databases, these statements must be routed to the
# correct repo for each table.
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE api_keys CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE document_components CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE documents CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE projects CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE workspace_members CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE workspaces CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE users_tokens CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE users CASCADE", [])

IO.puts("[exo-seeds] Seeding exo-bdd test data...")

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

  Identity.Domain.Entities.User.from_schema(updated_schema)
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

create_api_key = fn user_id, attrs ->
  # Use deterministic token if provided, otherwise generate random
  plain_token = Map.get(attrs, :token) || ApiKeyTokenService.generate_token()
  hashed_token = ApiKeyTokenService.hash_token(plain_token)

  api_key_attrs = %{
    name: Map.get(attrs, :name, "Test API Key"),
    description: Map.get(attrs, :description),
    hashed_token: hashed_token,
    user_id: user_id,
    workspace_access: Map.get(attrs, :workspace_access, []),
    is_active: Map.get(attrs, :is_active, true)
  }

  {:ok, schema} =
    %ApiKeySchema{}
    |> ApiKeySchema.changeset(api_key_attrs)
    |> Identity.Repo.insert()

  {ApiKeySchema.to_entity(schema), plain_token}
end

# ---------------------------------------------------------------------------
# 1. Create users
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

IO.puts("[exo-seeds] Created users: alice@example.com, bob@example.com")

# ---------------------------------------------------------------------------
# 2. Create workspaces
# ---------------------------------------------------------------------------

# Use deterministic UUIDs so feature files can reference workspace IDs as
# config variables (especially important for ERM which uses UUID-based routing).
# We call create_workspace_with_id/3 which sets the ID before insert.
create_workspace_with_id = fn user, attrs, deterministic_id ->
  # Insert workspace with a pre-set UUID so feature files can reference it.
  # Ecto respects a pre-populated :id field over autogenerate.
  alias Jarga.Workspaces.Infrastructure.Schemas.{WorkspaceSchema, WorkspaceMemberSchema}
  alias Jarga.Workspaces.Domain.Entities.Workspace

  now = DateTime.utc_now() |> DateTime.truncate(:second)

  {:ok, result} =
    Jarga.Repo.transaction(fn ->
      {:ok, ws_schema} =
        %WorkspaceSchema{id: deterministic_id}
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
          user_id: user.id,
          email: user.email,
          role: :owner,
          invited_at: now,
          joined_at: now
        })
        |> Jarga.Repo.insert()

      Workspace.from_schema(ws_schema)
    end)

  {:ok, result}
end

{:ok, product_team} =
  create_workspace_with_id.(
    alice,
    %{
      name: "Product Team",
      slug: "product-team",
      description: "Product team workspace",
      color: "#4A90E2"
    },
    deterministic_workspace_ids["product-team"]
  )

{:ok, engineering} =
  create_workspace_with_id.(
    alice,
    %{
      name: "Engineering",
      slug: "engineering",
      description: "Engineering workspace",
      color: "#10B981"
    },
    deterministic_workspace_ids["engineering"]
  )

IO.puts("[exo-seeds] Created workspaces: #{product_team.slug}, #{engineering.slug}")

# ---------------------------------------------------------------------------
# 3. Add bob as a member of product-team
# ---------------------------------------------------------------------------

add_member_directly.(product_team.id, bob, :member)
IO.puts("[exo-seeds] Added bob as member of #{product_team.slug}")

# ---------------------------------------------------------------------------
# 4. Create projects
# ---------------------------------------------------------------------------

{:ok, q1_launch} =
  Projects.create_project(alice, product_team.id, %{
    name: "Q1 Launch",
    description: "Q1 product launch plan",
    color: "#F59E0B"
  })

IO.puts("[exo-seeds] Created project: #{q1_launch.slug} in #{product_team.slug}")

# ---------------------------------------------------------------------------
# 5. Create documents
# ---------------------------------------------------------------------------

# Product Spec - owned by alice in product-team (public)
{:ok, _product_spec} =
  Documents.create_document(alice, product_team.id, %{
    title: "Product Spec",
    content: "Detailed specifications",
    is_public: true
  })

# Shared Doc - owned by bob in product-team (public)
{:ok, _shared_doc} =
  Documents.create_document(bob, product_team.id, %{
    title: "Shared Doc",
    content: "Shared documentation",
    is_public: true
  })

# Bob's Private Doc - owned by bob in product-team (private)
{:ok, _bobs_private_doc} =
  Documents.create_document(bob, product_team.id, %{
    title: "Bobs Private Doc",
    content: "Bob's private notes",
    is_public: false
  })

# Launch Plan - in q1-launch project (public)
{:ok, _launch_plan} =
  Documents.create_document(alice, product_team.id, %{
    title: "Launch Plan",
    content: "Detailed launch plan",
    project_id: q1_launch.id,
    is_public: true
  })

IO.puts("[exo-seeds] Created documents: product-spec, shared-doc, bobs-private-doc, launch-plan")

# ---------------------------------------------------------------------------
# 6. Create a guest user (can view but not create documents)
# ---------------------------------------------------------------------------

guest =
  create_confirmed_user.(%{
    email: "guest@example.com",
    first_name: "Guest",
    last_name: "Viewer"
  })

add_member_directly.(product_team.id, guest, :guest)
IO.puts("[exo-seeds] Created guest user and added as guest of #{product_team.slug}")

# ---------------------------------------------------------------------------
# 7. Create API keys (deterministic tokens for exo-bdd)
# ---------------------------------------------------------------------------

# API key for alice with access to product-team (for document CRUD)
{_key, _} =
  create_api_key.(alice.id, %{
    name: "Doc Key (product-team)",
    workspace_access: [product_team.slug],
    token: deterministic_tokens["valid-doc-key-product-team"]
  })

# API key for alice with access to product-team (for reads)
{_key, _} =
  create_api_key.(alice.id, %{
    name: "Read Key (product-team)",
    workspace_access: [product_team.slug],
    token: deterministic_tokens["valid-read-key-product-team"]
  })

# API key for alice with access to engineering only (NOT product-team)
{_key, _} =
  create_api_key.(alice.id, %{
    name: "Engineering Key",
    workspace_access: [engineering.slug],
    token: deterministic_tokens["valid-key-engineering-only"]
  })

# Revoked API key
{_key, _} =
  create_api_key.(alice.id, %{
    name: "Revoked Key (product-team)",
    workspace_access: [product_team.slug],
    is_active: false,
    token: deterministic_tokens["revoked-key-product-team"]
  })

# API key for bob (member role = can create documents)
{_key, _} =
  create_api_key.(bob.id, %{
    name: "Member Key (product-team)",
    workspace_access: [product_team.slug],
    token: deterministic_tokens["valid-member-key-product-team"]
  })

# API key for guest user (guest role = can view but NOT create documents)
{_key, _} =
  create_api_key.(guest.id, %{
    name: "Guest Key (product-team)",
    workspace_access: [product_team.slug],
    token: deterministic_tokens["valid-guest-key-product-team"]
  })

# API key for alice with access to BOTH product-team AND engineering (multi-workspace)
{_key, _} =
  create_api_key.(alice.id, %{
    name: "Multi-Workspace Key",
    workspace_access: [product_team.slug, engineering.slug],
    token: deterministic_tokens["valid-multi-workspace-key"]
  })

# API key for alice with NO workspace access (empty list)
{_key, _} =
  create_api_key.(alice.id, %{
    name: "No Access Key",
    workspace_access: [],
    token: deterministic_tokens["valid-no-access-key"]
  })

# API key for alice with access to product-team AND a phantom workspace slug
# (ghost-workspace does not exist in the database -- tests the true 404 path)
{_key, _} =
  create_api_key.(alice.id, %{
    name: "Phantom Workspace Key",
    workspace_access: [product_team.slug, "ghost-workspace"],
    token: deterministic_tokens["valid-phantom-workspace-key"]
  })

IO.puts("[exo-seeds] Created API keys with deterministic tokens")
IO.puts("[exo-seeds] Done!")
