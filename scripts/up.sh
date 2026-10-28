#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required." >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "Docker is installed but the daemon is not running. Start Docker Desktop and retry." >&2
  exit 1
fi
if ! command -v liquibase >/dev/null 2>&1; then
  echo "Liquibase is not on PATH. Install it with: brew install --cask liquibase-community" >&2
  exit 1
fi
if [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
  echo "Java 17+ was not found at JAVA_HOME=${JAVA_HOME}." >&2
  echo "Install it with: brew install openjdk@21" >&2
  exit 1
fi

ensure_postgres_driver
docker compose up -d --wait
echo "PostgreSQL 16.11 is ready on localhost:${POSTGRES_PORT}, database ${DATABASE_NAME}."
