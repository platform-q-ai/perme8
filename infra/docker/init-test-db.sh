#!/bin/bash
# Creates the test database alongside the default jarga_dev database.
# This script runs automatically on first container start via
# docker-entrypoint-initdb.d (PostgreSQL's built-in init mechanism).
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE jarga_test;
EOSQL
