.PHONY: help up down reset status update update-sql history validate rollback-count rollback-tag release-locks psql demos

help:
	@printf '%s\n' \
		'make up                  start PostgreSQL 16.11 and install the JDBC driver if needed' \
		'make down                stop PostgreSQL and keep the data volume' \
		'make reset               delete the data volume and start a fresh database' \
		'make status              list changesets not yet applied' \
		'make update-sql          print the SQL Liquibase would run' \
		'make update              apply pending changesets' \
		'make history             show changesets already applied' \
		'make validate            check changelog syntax and checksums' \
		'make rollback-count N=1  roll back the last N changesets' \
		'make rollback-tag TAG=v1.0.0' \
		'make release-locks       clear a stuck DATABASECHANGELOGLOCK row' \
		'make psql ROLE=liquibase open psql as super, liquibase, app, or limited' \
		'make demos               run failure, rollback, checksum, context, and lock demos'

up:
	./scripts/up.sh

down:
	./scripts/down.sh

reset:
	./scripts/reset.sh

status:
	./scripts/lb.sh status

update-sql:
	./scripts/lb.sh update-sql

update:
	./scripts/lb.sh update

history:
	./scripts/lb.sh history

validate:
	./scripts/lb.sh validate

rollback-count:
	@test -n "$(N)" || { echo "Usage: make rollback-count N=1" >&2; exit 1; }
	./scripts/lb.sh rollback-count "$(N)"

rollback-tag:
	@test -n "$(TAG)" || { echo "Usage: make rollback-tag TAG=v1.0.0" >&2; exit 1; }
	./scripts/lb.sh rollback "$(TAG)"

release-locks:
	./scripts/lb.sh release-locks

psql:
	./scripts/psql.sh $(or $(ROLE),liquibase)

demos:
	./scripts/demos.sh
