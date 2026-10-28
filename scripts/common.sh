#!/usr/bin/env bash
# Shared paths, local credentials, and the Java runtime Liquibase uses.
# Sourced by the other scripts. Do not execute directly.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home}"
export PATH="${JAVA_HOME}/bin:${PATH}"

export LIQUIBASE_COMMAND_URL="jdbc:postgresql://localhost:${POSTGRES_PORT}/${DATABASE_NAME}"
export LIQUIBASE_COMMAND_USERNAME="${MIGRATION_USERNAME}"
export LIQUIBASE_COMMAND_PASSWORD="${MIGRATION_PASSWORD}"

liquibase_home() {
  local prg link
  prg="$(command -v liquibase)"
  while [[ -L "$prg" ]]; do
    link="$(readlink "$prg")"
    if [[ "$link" == /* ]]; then
      prg="$link"
    else
      prg="$(cd "$(dirname "$prg")" && pwd)/$link"
    fi
  done
  cd "$(dirname "$prg")" && pwd
}

ensure_postgres_driver() {
  local home lpm
  home="$(liquibase_home)"
  lpm="${home}/lpm"
  if [[ ! -x "$lpm" ]]; then
    liquibase lpm --download
  fi
  if ! compgen -G "liquibase_libs/postgresql-*.jar" > /dev/null; then
    "$lpm" install
  fi
}

psql_as() {
  local user="$1"
  local pass="$2"
  shift 2
  local tty_flags=(-i)
  if [[ -t 0 && $# -eq 0 ]]; then
    tty_flags=(-it)
  fi
  docker exec "${tty_flags[@]}" -e PGPASSWORD="$pass" liquibase_poc_postgres \
    psql -v ON_ERROR_STOP=1 -U "$user" -d "$DATABASE_NAME" "$@"
}
