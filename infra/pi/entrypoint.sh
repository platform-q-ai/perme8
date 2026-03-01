#!/bin/bash
set -eo pipefail

BRANCH="${REPO_BRANCH:-main}"
PEM_PATH="$HOME/.config/perme8/private-key.pem"
GET_TOKEN="$HOME/.config/perme8/get-token"

# ---- Validate required env vars ----

if [ -z "$GITHUB_APP_PEM" ]; then
  echo "error: GITHUB_APP_PEM is required (base64-encoded GitHub App private key)" >&2
  exit 1
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "error: ANTHROPIC_API_KEY is required for Pi LLM authentication" >&2
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

# ---- Clone repos ----

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

# ---- Install Pi project-level configuration ----
# Copy the .pi directory from the image into the repo clone so Pi discovers
# the agents, extensions, prompts, and settings at startup.

if [ -d /workspace/pi ]; then
  echo "Installing Pi project configuration into repo..."
  cp -r /workspace/pi /workspace/perme8/.pi
fi

# ---- Start embedded PostgreSQL ----

PGDATA="/tmp/pgdata"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
  echo "Initializing PostgreSQL data directory..."
  initdb -D "$PGDATA" --auth=trust --no-locale --encoding=UTF8

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

createuser -h localhost -s postgres 2>/dev/null || true

# ---- Build the Elixir project ----

echo "Setting up Elixir project..."
export DATABASE_URL="postgres://postgres:postgres@localhost/jarga_dev"

mix local.hex --force --if-missing
mix local.rebar --force --if-missing
mix deps.get

npm install --prefix apps/jarga_web/assets
npm install --prefix apps/agents_web/assets

MIX_ENV=dev mix compile
MIX_ENV=test mix compile

# ---- Set up databases ----

echo "Setting up dev database..."
MIX_ENV=dev mix ecto.create --quiet
MIX_ENV=dev mix ecto.migrate --quiet
echo "Dev database ready"

echo "Setting up test database..."
MIX_ENV=test mix ecto.create --quiet
MIX_ENV=test mix ecto.migrate --quiet
echo "Test database ready"

unset MIX_ENV
unset DATABASE_URL

# ---- Start Pi in RPC mode ----
# Pi communicates via stdin/stdout JSON protocol.
# The runtime adapter spawns this container and talks to Pi over stdio.
# --no-session: ephemeral mode (session managed externally)
# --model: use Claude Opus 4 via Anthropic API

exec pi --mode rpc --no-session --model anthropic/claude-opus-4-6
