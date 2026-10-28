#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

role="${1:-liquibase}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "$role" in
  super|postgres)
    psql_as "$POSTGRES_SUPERUSER" "$POSTGRES_SUPERUSER_PASSWORD" "$@"
    ;;
  liquibase|admin)
    psql_as "$MIGRATION_USERNAME" "$MIGRATION_PASSWORD" "$@"
    ;;
  app)
    psql_as "$APP_USERNAME" "$APP_PASSWORD" "$@"
    ;;
  limited)
    psql_as "$LIMITED_USERNAME" "$LIMITED_PASSWORD" "$@"
    ;;
  *)
    echo "usage: scripts/psql.sh [super|liquibase|app|limited] [psql args...]" >&2
    exit 1
    ;;
esac
