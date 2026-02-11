#!/usr/bin/env bash
# exit on error
set -o errexit

# Install dependencies
mix deps.get --only prod

# Install npm dependencies for assets
npm install --prefix apps/jarga_web/assets

# Compile the application
MIX_ENV=prod mix compile

# Build assets
MIX_ENV=prod mix assets.build
MIX_ENV=prod mix assets.deploy

# Generate release wrapper scripts (must run inside the web app for umbrella projects)
(cd apps/jarga_web && MIX_ENV=prod mix phx.gen.release)

# Create the release
MIX_ENV=prod mix release --overwrite
