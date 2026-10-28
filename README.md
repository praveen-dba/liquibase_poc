# Liquibase PostgreSQL POC

Local Liquibase Community setup for PostgreSQL. The changelog in this repo is the source of truth. Liquibase applies it, records what ran, and can roll it back.

This was installed and exercised on this Mac on 28 October 2026.

| Piece | Version |
| --- | --- |
| Liquibase Community | 5.0.4 |
| Java | OpenJDK 21.0.13 (Homebrew `openjdk@21`) |
| PostgreSQL | 16.11, image `postgres:16.11` (`postgres@sha256:468e1f126ca5af849799cda06ac9b03d8090aae9fa5163408b3e8da44fad0702`) |
| PostgreSQL JDBC driver | 42.7.14, installed with Liquibase Package Manager |
| Database | `appdb` on `localhost:5432` |

## Documents

- [What Liquibase is, and why use it](docs/01-what-is-liquibase.md)
- [PostgreSQL local setup](docs/02-postgresql-local-setup.md)
- [Tracking tables, permissions, versioning, and rollback](docs/03-how-it-works.md)

## Layout

```text
changelog/          changesets Liquibase applies, in order
  db.changelog-master.yaml
  changes/          the real schema changes
  demos/            failure, rollback, and context examples
db/init/            roles and schemas created when the volume is first initialized
db/inspect/         queries used to look at privileges and the tracking tables
scripts/            start, stop, Liquibase, psql, and the side-case demos
liquibase.properties
liquibase.json      JDBC driver version LPM installs into liquibase_libs/
docker-compose.yml  PostgreSQL 16.11
```

`liquibase_libs/`, `.env`, and `target/` are local. They are not part of the commit.

## Run it

Docker Desktop has to be running.

```bash
make up
make status
make update
make history
```

A second `make update` reports that the database is already up to date.

Other targets:

```bash
make update-sql                 # print the SQL, do not apply it
make validate
make rollback-count N=1
make rollback-tag TAG=v1.0.0
make release-locks
make psql ROLE=liquibase        # super, liquibase, app, or limited
make demos                      # failure, checksum, context, tag, and lock cases
make down                       # stop the container, keep the data
make reset                      # delete the volume and start clean
```

The Makefile calls `scripts/lb.sh`, which sets `JAVA_HOME` and the database URL. A bare `liquibase` in a new terminal will not find Java until `JAVA_HOME` points at Homebrew OpenJDK 21.

Passwords live in `.env`, copied from `.env.example` on the first `make up`. They are local-only values.
