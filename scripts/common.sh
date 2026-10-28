#!/usr/bin/env bash
# Shared paths, local credentials, and the Java runtime Liquibase uses.
# Sourced by scripts/lb.sh. Do not execute directly.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Values already exported by the caller (a Jenkins job, a shell) win over .env.
pre_url="${LIQUIBASE_COMMAND_URL-}"
pre_user="${LIQUIBASE_COMMAND_USERNAME-}"
pre_pass="${LIQUIBASE_COMMAND_PASSWORD-}"
pre_pass_set=0
if [[ -n "${LIQUIBASE_COMMAND_PASSWORD+x}" ]]; then
  pre_pass_set=1
fi

if [[ -z "$pre_url" && ! -f "${ROOT}/.env" && -f "${ROOT}/.env.example" ]]; then
  cp "${ROOT}/.env.example" "${ROOT}/.env"
fi

if [[ -f "${ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${ROOT}/.env"
  set +a
fi

if [[ -n "$pre_url" ]]; then
  LIQUIBASE_COMMAND_URL="$pre_url"
fi
if [[ -n "$pre_user" ]]; then
  LIQUIBASE_COMMAND_USERNAME="$pre_user"
fi
if [[ "$pre_pass_set" -eq 1 ]]; then
  LIQUIBASE_COMMAND_PASSWORD="$pre_pass"
fi

# Liquibase 5 rejects LIQUIBASE_USERNAME and LIQUIBASE_PASSWORD.
unset LIQUIBASE_USERNAME LIQUIBASE_PASSWORD || true

if [[ -z "${JAVA_HOME:-}" && -x /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home/bin/java ]]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
fi
if [[ -n "${JAVA_HOME:-}" ]]; then
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

apply_engine_credentials() {
  local engine="$1"
  local prefix url_var user_var pass_var

  case "$engine" in
    postgres) prefix=POSTGRES ;;
    mysql) prefix=MYSQL ;;
    mongodb) prefix=MONGODB ;;
    *)
      echo "ENGINE must be mysql, postgres, or mongodb." >&2
      return 1
      ;;
  esac

  url_var="${prefix}_URL"
  user_var="${prefix}_USERNAME"
  pass_var="${prefix}_PASSWORD"

  if [[ -z "${LIQUIBASE_COMMAND_URL:-}" ]]; then
    LIQUIBASE_COMMAND_URL="${!url_var:-}"
  fi
  if [[ -z "${LIQUIBASE_COMMAND_USERNAME:-}" ]]; then
    LIQUIBASE_COMMAND_USERNAME="${!user_var:-}"
  fi
  if [[ -z "${LIQUIBASE_COMMAND_PASSWORD+x}" ]]; then
    LIQUIBASE_COMMAND_PASSWORD="${!pass_var:-}"
  fi

  if [[ -z "${LIQUIBASE_COMMAND_URL:-}" ]]; then
    echo "No connection URL for ${engine}." >&2
    echo "Set ${url_var} in .env, or export LIQUIBASE_COMMAND_URL." >&2
    return 1
  fi

  if [[ "$engine" == "mongodb" && -z "${LIQUIBASE_COMMAND_USERNAME:-}" ]]; then
    unset LIQUIBASE_COMMAND_USERNAME LIQUIBASE_COMMAND_PASSWORD
    export LIQUIBASE_COMMAND_URL
    return 0
  fi

  if [[ -z "${LIQUIBASE_COMMAND_USERNAME:-}" ]]; then
    echo "No username for ${engine}." >&2
    echo "Set ${user_var} in .env, or export LIQUIBASE_COMMAND_USERNAME." >&2
    return 1
  fi

  export LIQUIBASE_COMMAND_URL LIQUIBASE_COMMAND_USERNAME LIQUIBASE_COMMAND_PASSWORD
}

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

ensure_drivers() {
  local home lpm missing
  if ! command -v liquibase >/dev/null 2>&1; then
    echo "Liquibase is not on PATH. Install it with: brew install --cask liquibase-community" >&2
    return 1
  fi
  if [[ -n "${JAVA_HOME:-}" && ! -x "${JAVA_HOME}/bin/java" ]]; then
    echo "Java was not found at JAVA_HOME=${JAVA_HOME}." >&2
    echo "Install it with: brew install openjdk@21" >&2
    return 1
  fi

  home="$(liquibase_home)"
  lpm="${home}/lpm"
  if [[ ! -x "$lpm" ]]; then
    (cd "$ROOT" && liquibase lpm --download)
  fi

  missing=0
  compgen -G "${ROOT}/liquibase_libs/postgresql-*.jar" >/dev/null || missing=1
  if ! compgen -G "${ROOT}/liquibase_libs/mysql-connector-java-*.jar" >/dev/null \
    && ! compgen -G "${ROOT}/liquibase_libs/mysql-connector-j-*.jar" >/dev/null; then
    missing=1
  fi
  compgen -G "${ROOT}/liquibase_libs/liquibase-mongodb-*.jar" >/dev/null || missing=1
  if ! compgen -G "${ROOT}/liquibase_libs/mongo-java-driver-*.jar" >/dev/null \
    && ! compgen -G "${ROOT}/liquibase_libs/mongodb-driver-sync-*.jar" >/dev/null; then
    missing=1
  fi
  if [[ "$missing" -eq 1 ]]; then
    (cd "$ROOT" && "$lpm" install)
  fi
}
