#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

TEAM="${TEAM:-service-team-a}"
defaults_file="${ROOT}/${TEAM}/liquibase.properties"

if [[ ! -f "$defaults_file" ]]; then
  echo "Unknown team '${TEAM}'." >&2
  echo "Use TEAM=service-team-a or TEAM=service-team-b." >&2
  exit 1
fi

# Run from the repo root so liquibase_libs/ is on the classpath.
# The team properties file supplies the changelog and the tracking table names.
# search-path is the team directory, matching changeLogFile=db/root-changelog.yaml.
cd "$ROOT"
exec liquibase \
  --defaults-file="$defaults_file" \
  --search-path="${ROOT}/${TEAM}" \
  "$@"
