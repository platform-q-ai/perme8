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

# Create the release
MIX_ENV=prod mix release perme8 --overwrite
