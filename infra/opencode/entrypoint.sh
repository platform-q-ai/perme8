#!/bin/sh
set -e

BRANCH="${REPO_BRANCH:-main}"
AUTH="https://x-access-token:${GITHUB_TOKEN}@github.com"

if [ -z "$GITHUB_TOKEN" ]; then
  echo "error: GITHUB_TOKEN is required" >&2
  exit 1
fi

if [ -z "$ANTHROPIC_REFRESH_TOKEN" ]; then
  echo "error: ANTHROPIC_REFRESH_TOKEN is required" >&2
  exit 1
fi

# Write opencode auth using Claude Max OAuth refresh token
mkdir -p /home/appuser/.local/share/opencode
cat > /home/appuser/.local/share/opencode/auth.json <<EOF
{
  "anthropic": {
    "type": "oauth",
    "refresh": "${ANTHROPIC_REFRESH_TOKEN}"
  }
}
EOF

echo "Cloning perme8 (branch: $BRANCH)..."
git clone --depth 1 --branch "$BRANCH" "${AUTH}/platform-q-ai/perme8.git" /workspace/perme8

echo "Cloning skills into ~/.claude/..."
git clone --depth 1 "${AUTH}/platform-q-ai/skills.git" /home/appuser/.claude

cd /workspace/perme8

# Copy opencode config into the repo root
cp /workspace/opencode.json /workspace/perme8/opencode.json

exec opencode serve --hostname 0.0.0.0 --port 4096
