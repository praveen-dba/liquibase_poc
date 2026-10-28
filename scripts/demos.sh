#!/usr/bin/env bash
# Side cases that are not part of the main changelog.
# Starts from a fully applied main changelog and leaves that state in place.
set -euo pipefail
source "$(dirname "$0")/common.sh"

restore_checksum_probe() {
  if [[ -f target/001.orig ]]; then
    cp target/001.orig changelog/changes/001-create-customers.sql
    rm -f target/001.orig
  fi
}
trap restore_checksum_probe EXIT

psql_super() {
  psql_as "$POSTGRES_SUPERUSER" "$POSTGRES_SUPERUSER_PASSWORD" "$@"
}

echo "===== transactional failure ====="
if liquibase --changelog-file=changelog/demos/failing-changeset.sql update; then
  echo "expected the failing changeset to abort" >&2
  exit 1
fi
psql_super -c "SELECT to_regclass('app.should_not_exist') AS should_not_exist, count(*) AS failed_rows FROM liquibase.databasechangelog WHERE id = 'demo-fail-mid-changeset';"

echo "===== failure with runInTransaction:false ====="
if liquibase --changelog-file=changelog/demos/failing-no-transaction.sql update; then
  echo "expected the non-transactional changeset to abort" >&2
  exit 1
fi
psql_super -c "SELECT to_regclass('app.partial_apply_demo') AS partial_table, count(*) AS recorded_rows FROM liquibase.databasechangelog WHERE id = 'demo-fail-no-transaction';"
psql_super -c "DROP TABLE IF EXISTS app.partial_apply_demo;"

echo "===== changeset with no rollback ====="
liquibase --changelog-file=changelog/demos/no-rollback.sql update
if liquibase --changelog-file=changelog/demos/no-rollback.sql rollback-count 1; then
  echo "expected rollback to refuse a changeset with no rollback" >&2
  exit 1
fi
psql_super <<'SQL'
DROP TABLE IF EXISTS app.no_rollback_demo;
DELETE FROM liquibase.databasechangelog WHERE id = 'demo-no-rollback';
SQL

echo "===== context filter ====="
liquibase --changelog-file=changelog/demos/context-demo.sql --contexts=prod update
liquibase --changelog-file=changelog/demos/context-demo.sql --contexts=dev update
psql_super -c "SELECT to_regclass('app.dev_notes') AS dev_notes;"
liquibase --changelog-file=changelog/demos/context-demo.sql rollback-count 1
psql_super -c "SELECT to_regclass('app.dev_notes') AS dev_notes_after_rollback;"

echo "===== checksum mismatch ====="
mkdir -p target
cp changelog/changes/001-create-customers.sql target/001.orig
printf '\n-- checksum probe\n' >> changelog/changes/001-create-customers.sql
if liquibase validate; then
  echo "expected validate to reject the edited changeset" >&2
  exit 1
fi
restore_checksum_probe
liquibase validate

echo "===== tag command keeps the tagged row ====="
liquibase tag cli-marker
mkdir -p target/tag-demo
cat > target/tag-demo/after-tag.sql <<'SQL'
--liquibase formatted sql

--changeset praveen:demo-after-cli-tag
CREATE TABLE app.after_cli_tag (
    id bigint PRIMARY KEY
);
--rollback DROP TABLE app.after_cli_tag;
SQL
liquibase --changelog-file=target/tag-demo/after-tag.sql update
liquibase --changelog-file=target/tag-demo/after-tag.sql rollback --tag=cli-marker
psql_super -c "SELECT id, tag FROM liquibase.databasechangelog WHERE id IN ('007-customer-count-fn', 'demo-after-cli-tag') ORDER BY orderexecuted;"
psql_super -c "SELECT to_regclass('app.after_cli_tag') AS after_cli_tag;"
psql_super -c "UPDATE liquibase.databasechangelog SET tag = NULL WHERE id = '007-customer-count-fn' AND tag = 'cli-marker';"

echo "===== stuck lock ====="
psql_super -c "UPDATE liquibase.databasechangeloglock SET locked = true, lockgranted = now(), lockedby = 'manual-demo' WHERE id = 1;"
liquibase list-locks
# status does not take the lock. update does, once there is a pending changeset.
if liquibase --changelog-lock-wait-time-in-minutes=0 \
  --changelog-file=changelog/demos/context-demo.sql --contexts=dev update; then
  echo "expected update to stop while the changelog lock is held" >&2
  exit 1
fi
liquibase release-locks
liquibase status

echo "===== generate a baseline, not used as the source of truth ====="
mkdir -p target
liquibase generate-changelog --changelog-file=target/generated-baseline.yaml --schemas=app

echo "Demos finished. Main changelog is unchanged."
