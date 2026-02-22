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

AUTH="https://x-access-token:${GITHUB_TOKEN}@github.com"

# ---- Configure git identity (perme8[bot]) ----

git config --global user.name "perme8[bot]"
git config --global user.email "262472400+perme8[bot]@users.noreply.github.com"

# ---- Write opencode auth from env var ----

mkdir -p "$HOME/.local/share/opencode" "$HOME/.local/state"
echo "$OPENCODE_AUTH" | base64 -d > "$HOME/.local/share/opencode/auth.json"
echo "opencode auth.json written"

# ---- Clone repos ----

echo "Cloning perme8 (branch: $BRANCH)..."
git clone --depth 1 --branch "$BRANCH" "${AUTH}/platform-q-ai/perme8.git" /workspace/perme8

echo "Cloning skills into ~/.claude/..."
git clone --depth 1 "${AUTH}/platform-q-ai/skills.git" "$HOME/.claude" || echo "warn: skills repo not available, skipping"

cd /workspace/perme8

# Configure push remote to use token (refreshable via get-token)
git remote set-url origin "${AUTH}/platform-q-ai/perme8.git"

# Copy opencode config into the repo root
cp /workspace/opencode.json /workspace/perme8/opencode.json

exec opencode serve --hostname 0.0.0.0 --port 4096
