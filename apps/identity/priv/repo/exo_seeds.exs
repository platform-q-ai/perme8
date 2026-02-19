# ExoBDD Test Seed Data for Identity
#
# This script populates the database with fixture data required by the
# exo-bdd feature files in apps/identity/test/features/.
#
# Run with: MIX_ENV=test mix run --no-start apps/identity/priv/repo/exo_seeds.exs
#
# Uses --no-start to avoid binding to ports already in use by a running server.
# We start only the bare OTP dependencies needed for seeding: repos and PubSub.
#
# The data created here matches the "Assumes:" comments in the feature files.

IO.puts("[identity-exo-seeds] Starting dependencies...")

# Start the minimal OTP dependencies (no Phoenix endpoints)
Application.ensure_all_started(:postgrex)
Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:bcrypt_elixir)

# Start Ecto repo
{:ok, _} = Identity.Repo.start_link()

alias Identity.Application.Services.PasswordService
alias Identity.Infrastructure.Schemas.{UserSchema, UserTokenSchema}
alias Identity.Infrastructure.Services.TokenGenerator

# ---------------------------------------------------------------------------
# Deterministic reset password token for exo-bdd tests.
# This is a fixed 32-byte value that gets hashed before storage.
# The exo-bdd config maps the "resetToken" variable to the URL-encoded version.
# ---------------------------------------------------------------------------
deterministic_reset_token_raw = :binary.copy(<<0xEE>>, 32)
deterministic_reset_token_hashed = TokenGenerator.hash_token(deterministic_reset_token_raw)
deterministic_reset_token_encoded = TokenGenerator.encode_token(deterministic_reset_token_raw)

IO.puts("[identity-exo-seeds] Reset token (URL-encoded): #{deterministic_reset_token_encoded}")

# ---------------------------------------------------------------------------
# Clean up any existing seed data (idempotent re-runs)
# ---------------------------------------------------------------------------

IO.puts("[identity-exo-seeds] Cleaning previous seed data...")

# Truncate in dependency order (children first, then parents)
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE api_keys CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE users_tokens CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE workspace_members CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE workspaces CASCADE", [])
Ecto.Adapters.SQL.query!(Identity.Repo, "TRUNCATE users CASCADE", [])

IO.puts("[identity-exo-seeds] Seeding exo-bdd test data...")

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

create_confirmed_user = fn attrs ->
  password = Map.get(attrs, :password, "SecurePassword123!")

  {:ok, user} =
    attrs
    |> Map.delete(:password)
    |> Identity.register_user()

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

# ---------------------------------------------------------------------------
# 1. Create users
# ---------------------------------------------------------------------------

alice =
  create_confirmed_user.(%{
    email: "alice@example.com",
    first_name: "Alice",
    last_name: "Tester",
    password: "SecurePassword123!"
  })

IO.puts("[identity-exo-seeds] Created user: alice@example.com")

# ---------------------------------------------------------------------------
# 2. Create a valid reset password token for Alice
#    Uses the deterministic token so the exo-bdd config can reference it.
# ---------------------------------------------------------------------------

%UserTokenSchema{}
|> Ecto.Changeset.change(%{
  token: deterministic_reset_token_hashed,
  context: "reset_password",
  sent_to: alice.email,
  user_id: alice.id
})
|> Identity.Repo.insert!()

IO.puts("[identity-exo-seeds] Created reset password token for alice@example.com")

# ---------------------------------------------------------------------------
# 3. Create API keys for Alice (browser feature tests)
#    Seeds two keys: one active, one revoked, to test filtering and display.
# ---------------------------------------------------------------------------

{:ok, {_active_key, _token}} =
  Identity.create_api_key(alice.id, %{
    name: "Seeded Active Key",
    description: "Pre-seeded key for browser tests",
    workspace_access: []
  })

IO.puts("[identity-exo-seeds] Created active API key for alice@example.com")

{:ok, {revoke_target, _token2}} =
  Identity.create_api_key(alice.id, %{
    name: "Seeded Revoked Key",
    description: "Pre-seeded revoked key for browser tests",
    workspace_access: []
  })

{:ok, _revoked} = Identity.revoke_api_key(alice.id, revoke_target.id)

IO.puts("[identity-exo-seeds] Created and revoked API key for alice@example.com")

IO.puts("[identity-exo-seeds] Done!")
