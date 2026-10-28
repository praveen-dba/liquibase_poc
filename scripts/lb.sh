#!/usr/bin/env bash
# One entry point for a laptop and for Jenkins.
#   TEAM=service-team-a ENGINE=postgres ./scripts/lb.sh update
#   TEAM=service-team-b ENGINE=mysql SCHEMA=app ./scripts/lb.sh update-sql
# Jenkins exports TEAM, ENGINE, SCHEMA, LIQUIBASE_COMMAND_URL,
# LIQUIBASE_COMMAND_USERNAME, and LIQUIBASE_COMMAND_PASSWORD, then calls this script.
set -euo pipefail
source "$(dirname "$0")/common.sh"

TEAM="${TEAM:-service-team-a}"
ENGINE="${ENGINE:-postgres}"
SCHEMA="${SCHEMA:-app}"

case "$TEAM" in
  service-team-a|service-team-b) ;;
  *)
    echo "Unknown team '${TEAM}'." >&2
    echo "Use TEAM=service-team-a or TEAM=service-team-b." >&2
    exit 1
    ;;
esac

case "$ENGINE" in
  mysql|postgres|mongodb) ;;
  *)
    echo "ENGINE must be mysql, postgres, or mongodb." >&2
    exit 1
    ;;
esac

defaults_file="${ROOT}/${TEAM}/db/${ENGINE}/liquibase.properties"
if [[ ! -f "$defaults_file" ]]; then
  echo "No properties file at ${defaults_file}." >&2
  exit 1
fi

ensure_drivers
apply_engine_credentials "$ENGINE"

cd "$ROOT"
args=(
  --defaults-file="$defaults_file"
  --search-path="${ROOT}/${TEAM}/db/${ENGINE}"
)
if [[ "$ENGINE" != "mongodb" ]]; then
  args+=(
    --liquibase-schema-name="$SCHEMA"
    --default-schema-name="$SCHEMA"
  )
fi

# -D is a command argument in Liquibase 5, so it has to follow the command name.
global=()
command_args=()
seen_command=0
for arg in "$@"; do
  if [[ "$seen_command" -eq 0 && "$arg" != -* ]]; then
    command_args+=("$arg")
    if [[ "$ENGINE" != "mongodb" ]]; then
      command_args+=("-DschemaName=${SCHEMA}")
    fi
    seen_command=1
  elif [[ "$seen_command" -eq 0 ]]; then
    global+=("$arg")
  else
    command_args+=("$arg")
  fi
done

exec liquibase "${args[@]}" "${global[@]}" "${command_args[@]}"
