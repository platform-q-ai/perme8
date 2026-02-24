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

if [ ! -d "$HOME/.claude/skills" ]; then
  echo "Cloning skills into ~/.claude/skills/..."
  mkdir -p "$HOME/.claude"
  git clone --depth 1 "https://github.com/platform-q-ai/skills.git" "$HOME/.claude/skills" || echo "warn: skills repo not available, skipping"
fi

# Copy opencode config into the repo root
cp /workspace/opencode.json /workspace/perme8/opencode.json

exec opencode serve --hostname 0.0.0.0 --port 4096
