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

grep -q GIT_TERMINAL_PROMPT "$HOME/.bashrc" 2>/dev/null || \
  echo 'export GIT_TERMINAL_PROMPT=0' >> "$HOME/.bashrc"

# ---- Write opencode auth from env var ----

mkdir -p "$HOME/.local/share/opencode" "$HOME/.local/state"
if [ ! -f "$HOME/.local/share/opencode/auth.json" ]; then
  echo "$OPENCODE_AUTH" | base64 -d > "$HOME/.local/share/opencode/auth.json"
  echo "opencode auth.json seeded from OPENCODE_AUTH env var"
else
  echo "opencode auth.json already exists, preserving (tokens may have been refreshed)"
fi

# ---- Refresh OpenAI auth internally before starting server ----

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

if [ -z "$MCP_KEY" ]; then
  echo "warn: PERME8_MCP_API_KEY is not set; MCP tool calls will fail authentication" >&2
fi

jq --arg url "$MCP_URL" --arg key "$MCP_KEY" \
  '.mcp["perme8-mcp"].url = $url | .mcp["perme8-mcp"].headers.Authorization = "Bearer \($key)"' \
  /workspace/opencode.json > /workspace/perme8/opencode.json

# ---- No database, no compilation, no asset pipeline ----
# This is a lightweight image for discussion/planning only.
# PostgreSQL, Elixir/Erlang, Node.js, and build tools are not installed.

exec opencode serve --hostname 0.0.0.0 --port 4096
