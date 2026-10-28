TEAM ?= service-team-a
ENGINE ?= postgres
SCHEMA ?= app

.PHONY: help drivers status update update-sql history validate rollback-count release-locks

help:
	@printf '%s\n' \
		'make drivers                     install the MySQL, MongoDB, and PostgreSQL jars from liquibase.json' \
		'make status                      pending changesets for TEAM and ENGINE' \
		'make update                      apply pending changesets' \
		'make update-sql                  print the SQL or statements Liquibase would run' \
		'make history                     show changesets already applied' \
		'make validate                    check changelog syntax and checksums' \
		'make rollback-count N=1          roll back the last N changesets' \
		'make release-locks               clear a stuck lock for this team and engine' \
		'' \
		'TEAM=service-team-a ENGINE=mysql make update' \
		'TEAM=service-team-b ENGINE=mongodb make status' \
		'TEAM=service-team-a ENGINE=postgres SCHEMA=app make update-sql' \
		'' \
		'Jenkins calls scripts/lb.sh with the same TEAM, ENGINE, and SCHEMA variables.'

drivers:
	bash -c 'set -euo pipefail; source ./scripts/common.sh; ensure_drivers; echo "Drivers are in liquibase_libs/"'

status:
	TEAM="$(TEAM)" ENGINE="$(ENGINE)" SCHEMA="$(SCHEMA)" ./scripts/lb.sh status

update-sql:
	TEAM="$(TEAM)" ENGINE="$(ENGINE)" SCHEMA="$(SCHEMA)" ./scripts/lb.sh update-sql

update:
	TEAM="$(TEAM)" ENGINE="$(ENGINE)" SCHEMA="$(SCHEMA)" ./scripts/lb.sh update

history:
	TEAM="$(TEAM)" ENGINE="$(ENGINE)" SCHEMA="$(SCHEMA)" ./scripts/lb.sh history

validate:
	TEAM="$(TEAM)" ENGINE="$(ENGINE)" SCHEMA="$(SCHEMA)" ./scripts/lb.sh validate

rollback-count:
	@test -n "$(N)" || { echo "Usage: make rollback-count N=1" >&2; exit 1; }
	TEAM="$(TEAM)" ENGINE="$(ENGINE)" SCHEMA="$(SCHEMA)" ./scripts/lb.sh rollback-count "$(N)"

release-locks:
	TEAM="$(TEAM)" ENGINE="$(ENGINE)" SCHEMA="$(SCHEMA)" ./scripts/lb.sh release-locks
