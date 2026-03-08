#!/bin/bash
set -e

BRANCH="${REPO_BRANCH:-main}"
PEM_PATH="$HOME/.config/perme8/private-key.pem"
REVIEW_PEM_PATH="$HOME/.config/perme8/review-private-key.pem"
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

if [ -n "${GITHUB_REVIEW_APP_PEM:-}" ] && [ -z "${GITHUB_REVIEW_APP_ID:-}" ]; then
  echo "error: GITHUB_REVIEW_APP_ID is required when GITHUB_REVIEW_APP_PEM is set" >&2
  exit 1
fi

if [ -z "${GITHUB_REVIEW_APP_PEM:-}" ] && [ -n "${GITHUB_REVIEW_APP_ID:-}" ]; then
  echo "error: GITHUB_REVIEW_APP_PEM is required when GITHUB_REVIEW_APP_ID is set" >&2
  exit 1
fi

# ---- Write PEM from env var ----

echo "$GITHUB_APP_PEM" | base64 -d > "$PEM_PATH"
chmod 600 "$PEM_PATH"
echo "GitHub App PEM written to $PEM_PATH"

if [ -n "${GITHUB_REVIEW_APP_PEM:-}" ]; then
  echo "$GITHUB_REVIEW_APP_PEM" | base64 -d > "$REVIEW_PEM_PATH"
  chmod 600 "$REVIEW_PEM_PATH"
  export GITHUB_REVIEW_APP_PRIVATE_KEY_PATH="$REVIEW_PEM_PATH"
  export GITHUB_REVIEW_APP_OWNER="${GITHUB_REVIEW_APP_OWNER:-platform-q-ai}"
  echo "Review bot PEM written to $REVIEW_PEM_PATH"
else
  echo "warn: review bot credentials not configured; automated PR review runs cannot request changes"
fi

# ---- Configure GIT_ASKPASS for token-based auth ----
# Uses GIT_ASKPASS so the token is never persisted in .git/config.
# The get-token script regenerates short-lived tokens on each git operation.
# GIT_ASKPASS is invoked with a prompt argument; we check whether git is
# asking for the username or the password and respond accordingly.
#
# NOTE: GIT_ASKPASS and GIT_TERMINAL_PROMPT are persisted in gitconfig
# (not just exported) so they survive docker exec / bash -lc sessions
# which don't inherit entrypoint env vars.

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

# ---- Configure git identity and persist askpass ----

git config --global user.name "perme8[bot]"
git config --global user.email "262472400+perme8[bot]@users.noreply.github.com"
git config --global core.askPass "$GIT_ASKPASS_SCRIPT"

# GIT_TERMINAL_PROMPT is env-only (no gitconfig equivalent).
# Persist it so docker exec / bash -lc sessions inherit it.
grep -q GIT_TERMINAL_PROMPT "$HOME/.bashrc" 2>/dev/null || \
  echo 'export GIT_TERMINAL_PROMPT=0' >> "$HOME/.bashrc"

# ---- Write opencode auth from env var ----
# Only seed auth.json on first boot. On restarts, preserve the existing file
# so that tokens refreshed at runtime (by opencode) survive container restarts.

mkdir -p "$HOME/.local/share/opencode" "$HOME/.local/state"
if [ ! -f "$HOME/.local/share/opencode/auth.json" ]; then
  echo "$OPENCODE_AUTH" | base64 -d > "$HOME/.local/share/opencode/auth.json"
  echo "opencode auth.json seeded from OPENCODE_AUTH env var"
else
  echo "opencode auth.json already exists, preserving (tokens may have been refreshed)"
fi

# ---- Refresh OpenAI auth internally before starting server ----
# Do not re-copy auth from host on restart. Instead, try to refresh using the
# container's own auth state so resumed sessions use fresh tokens.

if python3 - <<'PY'
import json
from pathlib import Path

auth_path = Path.home() / ".local/share/opencode/auth.json"
try:
    providers = json.loads(auth_path.read_text())
except Exception:
    raise SystemExit(1)

openai = providers.get("openai")
if isinstance(openai, dict) and openai.get("type") == "oauth":
    raise SystemExit(0)
raise SystemExit(1)
PY
then
  echo "Refreshing OpenAI OAuth token inside container..."
  if opencode models openai >/tmp/opencode-openai-refresh.log 2>&1; then
    echo "OpenAI auth refresh check completed"
  else
    echo "warn: OpenAI auth refresh check failed; continuing with existing auth"
  fi
fi

# ---- Clone repos (first boot only; preserve checkout on restart) ----

if [ -d /workspace/perme8 ]; then
  echo "Repo already cloned, preserving existing checkout"
  cd /workspace/perme8
else
  echo "Cloning perme8 (branch: $BRANCH)..."
  git clone --depth 1 --branch "$BRANCH" "https://github.com/platform-q-ai/perme8.git" /workspace/perme8
  cd /workspace/perme8
fi

if [ -d "$HOME/.claude/skills" ]; then
  echo "Skills already cloned, preserving existing checkout"
  cd "$HOME/.claude/skills"
  cd /workspace/perme8
else
  echo "Cloning skills into ~/.claude/skills/..."
  mkdir -p "$HOME/.claude"
  git clone --depth 1 "https://github.com/platform-q-ai/skills.git" "$HOME/.claude/skills" || echo "warn: skills repo not available, skipping"
fi

# Copy opencode config into the repo root, substituting MCP connection vars.
# PERME8_MCP_URL defaults to the host's MCP server via Docker's host gateway.
# PERME8_MCP_API_KEY should be set to a valid API key for MCP auth.
MCP_URL="${PERME8_MCP_URL:-http://host.docker.internal:4007/}"
MCP_KEY="${PERME8_MCP_API_KEY:-}"
sed -e "s|__PERME8_MCP_URL__|${MCP_URL}|g" \
    -e "s|__PERME8_MCP_API_KEY__|${MCP_KEY}|g" \
    /workspace/opencode.json > /workspace/perme8/opencode.json

# ---- Start embedded PostgreSQL ----

PGDATA="/tmp/pgdata"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
  echo "Initializing PostgreSQL data directory..."
  initdb -D "$PGDATA" --auth=trust --no-locale --encoding=UTF8

  # Tune for ephemeral single-session use (no durability needed)
  cat >> "$PGDATA/postgresql.conf" <<'PGCONF'
listen_addresses = 'localhost'
port = 5432
max_connections = 200
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

# Install exo-bdd runner dependencies once (provides cucumber-js)
if [ ! -x tools/exo-bdd/node_modules/.bin/cucumber-js ]; then
  echo "Installing exo-bdd dependencies..."
  bun install --cwd tools/exo-bdd
else
  echo "exo-bdd dependencies already installed"
fi

MIX_ENV=dev mix compile
MIX_ENV=test mix compile

# ---- Set up the dev database ----

echo "Setting up dev database..."
MIX_ENV=dev mix ecto.create --quiet
MIX_ENV=dev mix ecto.migrate --quiet
echo "Dev database ready"

# ---- Set up the test database ----
# Everything runs on port 5432 — same as dev, just a different database name.
# .env.test provides DATABASE_URL=localhost/jarga_test for test commands.

echo "Setting up test database..."
MIX_ENV=test mix ecto.create --quiet
MIX_ENV=test mix ecto.migrate --quiet
echo "Test database ready"

# ---- Clear build-time env vars so agent commands use their own defaults ----
# MIX_ENV: mix test defaults to :test, mix compile defaults to :dev, etc.
# DATABASE_URL: dev config falls back to localhost/jarga_dev,
#               test config reads DATABASE_URL from .env.test.
unset MIX_ENV
unset DATABASE_URL

exec opencode serve --hostname 0.0.0.0 --port 4096
