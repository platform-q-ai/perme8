#!/bin/bash
set -e

BRANCH="${REPO_BRANCH:-main}"
PEM_PATH="$HOME/.config/perme8/private-key.pem"
GET_TOKEN="$HOME/.config/perme8/get-token"

# ---- Validate required env vars ----

if [ -z "$GITHUB_APP_PEM" ]; then
  echo "error: GITHUB_APP_PEM is required (base64-encoded GitHub App private key)" >&2
  exit 1
fi

if [ -z "$OPENCODE_AUTH" ]; then
  echo "error: OPENCODE_AUTH is required (base64-encoded opencode auth.json)" >&2
  exit 1
fi

# ---- Write PEM from env var ----

echo "$GITHUB_APP_PEM" | base64 -d > "$PEM_PATH"
chmod 600 "$PEM_PATH"
echo "GitHub App PEM written to $PEM_PATH"

# ---- Generate GitHub token ----

GITHUB_TOKEN=$("$GET_TOKEN")
export GITHUB_TOKEN
echo "GitHub installation token generated"

# ---- Configure GIT_ASKPASS for token-based auth ----
# Uses GIT_ASKPASS so the token is never persisted in .git/config.
# The get-token script regenerates short-lived tokens on each git operation.
# GIT_ASKPASS is invoked with a prompt argument; we check whether git is
# asking for the username or the password and respond accordingly.

GIT_ASKPASS_SCRIPT="$HOME/.config/perme8/git-askpass"
cat > "$GIT_ASKPASS_SCRIPT" <<'ASKPASS'
#!/bin/bash
case "$1" in
  Username*) echo "x-access-token" ;;
  Password*) exec "$HOME/.config/perme8/get-token" ;;
esac
ASKPASS
chmod +x "$GIT_ASKPASS_SCRIPT"

export GIT_ASKPASS="$GIT_ASKPASS_SCRIPT"
export GIT_TERMINAL_PROMPT=0

# ---- Configure git identity (perme8[bot]) ----

git config --global user.name "perme8[bot]"
git config --global user.email "262472400+perme8[bot]@users.noreply.github.com"

# ---- Write opencode auth from env var ----

mkdir -p "$HOME/.local/share/opencode" "$HOME/.local/state"
echo "$OPENCODE_AUTH" | base64 -d > "$HOME/.local/share/opencode/auth.json"
echo "opencode auth.json written"

# ---- Clone repos (skip on container restart when dirs already exist) ----

if [ -d /workspace/perme8 ]; then
  echo "Repo already cloned, pulling latest (branch: $BRANCH)..."
  cd /workspace/perme8
  git fetch origin "$BRANCH" --depth 1 && git reset --hard "origin/$BRANCH" || echo "warn: git pull failed, using existing checkout"
else
  echo "Cloning perme8 (branch: $BRANCH)..."
  git clone --depth 1 --branch "$BRANCH" "https://github.com/platform-q-ai/perme8.git" /workspace/perme8
  cd /workspace/perme8
fi

if [ -d "$HOME/.claude/skills" ]; then
  echo "Skills already cloned, pulling latest..."
  cd "$HOME/.claude/skills"
  git fetch origin --depth 1 && git reset --hard origin/main || echo "warn: skills pull failed, using existing checkout"
  cd /workspace/perme8
else
  echo "Cloning skills into ~/.claude/skills/..."
  mkdir -p "$HOME/.claude"
  git clone --depth 1 "https://github.com/platform-q-ai/skills.git" "$HOME/.claude/skills" || echo "warn: skills repo not available, skipping"
fi

# Copy opencode config into the repo root
cp /workspace/opencode.json /workspace/perme8/opencode.json

# ---- Start embedded PostgreSQL ----

PGDATA="/tmp/pgdata"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
  echo "Initializing PostgreSQL data directory..."
  initdb -D "$PGDATA" --auth=trust --no-locale --encoding=UTF8

  # Tune for ephemeral single-session use (no durability needed)
  cat >> "$PGDATA/postgresql.conf" <<'PGCONF'
listen_addresses = 'localhost'
port = 5432
max_connections = 50
shared_buffers = 32MB
work_mem = 4MB
fsync = off
synchronous_commit = off
full_page_writes = off
wal_level = minimal
max_wal_senders = 0
ssl = off
unix_socket_directories = '/tmp'
log_destination = 'stderr'
logging_collector = off
PGCONF
fi

echo "Starting PostgreSQL..."
pg_ctl start -D "$PGDATA" -l "$PGDATA/logfile" -o "-k /tmp -h localhost"

# Create the postgres superuser role to match the app's default credentials
createuser -h localhost -s postgres 2>/dev/null || true

# ---- Build the Elixir project ----
#
# IMPORTANT: DATABASE_URL and MIX_ENV are set per-command (not exported) so
# they don't leak into the opencode session. If MIX_ENV=dev were exported,
# `mix test` inside the agent session would inherit it and silently skip
# the :test environment — meaning elixirc_paths would resolve to ["lib"]
# instead of ["lib", "test/support"], causing modules like
# ExoDashboardWeb.ConnCase to not be compiled.

echo "Setting up Elixir project..."
export DATABASE_URL="postgres://postgres:postgres@localhost/jarga_dev"

mix local.hex --force --if-missing
mix local.rebar --force --if-missing
mix deps.get

# Install npm dependencies for asset pipelines
npm install --prefix apps/jarga_web/assets
npm install --prefix apps/agents_web/assets

MIX_ENV=dev mix compile
MIX_ENV=test mix compile

# ---- Set up the dev database ----

echo "Setting up dev database..."
MIX_ENV=dev mix ecto.create --quiet
MIX_ENV=dev mix ecto.migrate --quiet
echo "Dev database ready"

# ---- Set up the test database ----
# The embedded PostgreSQL runs on port 5432. config/test.exs falls back to
# localhost:5433 (matching docker-compose's test service), so we override
# DATABASE_URL to point at the local instance on 5432.

echo "Setting up test database..."
DATABASE_URL="postgres://postgres:postgres@localhost/jarga_test" MIX_ENV=test mix ecto.create --quiet
DATABASE_URL="postgres://postgres:postgres@localhost/jarga_test" MIX_ENV=test mix ecto.migrate --quiet
echo "Test database ready"

# ---- Override .env.test for embedded PostgreSQL ----
# The tracked .env.test has DATABASE_URL pointing to docker-compose port 5433.
# Inside the container, PostgreSQL runs on the standard port 5432.
# Overwriting the file is safe — git reset --hard restores it on container restart.

cat > /workspace/perme8/.env.test <<'ENVTEST'
# Test environment overrides (container version)
# Embedded PostgreSQL runs on port 5432, not 5433 like docker-compose.
DATABASE_URL=postgres://postgres:postgres@localhost/jarga_test

# Fast debounce time for tests (1ms instead of 2000ms)
PAGE_SAVE_DEBOUNCE_MS=1
ENVTEST
echo ".env.test overwritten for embedded PostgreSQL (port 5432)"

# ---- Clear build-time env vars so agent commands use their own defaults ----
# MIX_ENV: mix test defaults to :test, mix compile defaults to :dev, etc.
# DATABASE_URL: dev config falls back to localhost/jarga_dev (port 5432).
#               test config reads DATABASE_URL from .env.test (overwritten above).
unset MIX_ENV
unset DATABASE_URL

exec opencode serve --hostname 0.0.0.0 --port 4096
