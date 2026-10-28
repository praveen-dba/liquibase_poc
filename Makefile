TEAM ?= service-team-a

.PHONY: help up down reset status update update-sql history validate rollback-count release-locks psql update-all

help:
	@printf '%s\n' \
		'make up                         start PostgreSQL 16.11 and install the JDBC driver if needed' \
		'make down                       stop PostgreSQL and keep the data volume' \
		'make reset                      delete the data volume and start a fresh database' \
		'make status                     pending changesets for TEAM (default service-team-a)' \
		'make update                     apply pending changesets for TEAM' \
		'make update-all                 apply service-team-a, then service-team-b' \
		'make update-sql                 print the SQL Liquibase would run' \
		'make history                    show changesets already applied for TEAM' \
		'make validate                   check changelog syntax and checksums' \
		'make rollback-count N=1         roll back the last N changesets for TEAM' \
		'make release-locks              clear a stuck lock row for TEAM' \
		'make psql ROLE=liquibase        open psql as super, liquibase, app, or limited' \
		'' \
		'TEAM=service-team-b make update'

up:
	./scripts/up.sh

down:
	./scripts/down.sh

reset:
	./scripts/reset.sh

status:
	TEAM="$(TEAM)" ./scripts/lb.sh status

update-sql:
	TEAM="$(TEAM)" ./scripts/lb.sh update-sql

update:
	TEAM="$(TEAM)" ./scripts/lb.sh update

update-all:
	TEAM=service-team-a ./scripts/lb.sh update
	TEAM=service-team-b ./scripts/lb.sh update

history:
	TEAM="$(TEAM)" ./scripts/lb.sh history

validate:
	TEAM="$(TEAM)" ./scripts/lb.sh validate

rollback-count:
	@test -n "$(N)" || { echo "Usage: make rollback-count N=1" >&2; exit 1; }
	TEAM="$(TEAM)" ./scripts/lb.sh rollback-count "$(N)"

release-locks:
	TEAM="$(TEAM)" ./scripts/lb.sh release-locks

psql:
	./scripts/psql.sh $(or $(ROLE),liquibase)
