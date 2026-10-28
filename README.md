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

Each team has its own changelog and its own Liquibase tracking tables. They share one PostgreSQL database.

```text
service-team-a/
├── liquibase.properties
└── db/
    ├── root-changelog.yaml
    └── 2026/
        ├── jan/
        │   ├── V1.1__create_users_table.sql
        │   └── V1.2__add_indexes.sql
        └── feb/
            └── V2.1__update_user_schema.sql
service-team-b/
├── liquibase.properties
└── db/
    ├── root-changelog.yaml
    └── 2026/
        ├── jan/
        │   └── V1.1__create_orders_table.sql
        └── feb/
            └── V1.2__add_payment_status.sql
db/init/            roles and schemas created when the volume is first initialized
db/inspect/         queries for privileges and the tracking tables
scripts/            start, stop, Liquibase, and psql
liquibase.json      JDBC driver version installed into liquibase_libs/
docker-compose.yml  PostgreSQL 16.11
```

`service-team-a/liquibase.properties` records changes in `serviceteama_databasechangelog` and takes its lock in `serviceteama_databasechangelock`. Team B uses `serviceteamb_databasechangelog` and `serviceteamb_databasechangelock`. One team's `update` does not mark the other team's changesets as run.

`liquibase_libs/`, `.env`, and `target/` are local. They are not part of the commit.

## Run it

Docker Desktop has to be running.

```bash
make up
make update TEAM=service-team-a
make update TEAM=service-team-b
make history TEAM=service-team-a
```

`make update` with no `TEAM` applies service-team-a. `make update-all` applies team A, then team B.

```bash
make status TEAM=service-team-b
make update-sql TEAM=service-team-a
make validate TEAM=service-team-a
make rollback-count TEAM=service-team-b N=1
make release-locks TEAM=service-team-a
make psql ROLE=liquibase
make down
make reset
```

The tracking tables are created in schema `app`, because that is the first schema on `liquibase_admin`'s search path and the team properties file sets only the table name. On a clean database this produced `app.serviceteama_databasechangelog` and `app.serviceteamb_databasechangelog`.

`appdb` still has the tables from the first changelog, including `app.orders`. Team B's `V1.1__create_orders_table.sql` will fail there until the volume is recreated with `make reset`. The team changelogs were applied successfully on a separate database, `teamdb`, in the same PostgreSQL 16.11 instance.

The Makefile calls `scripts/lb.sh`, which sets `JAVA_HOME` and the database URL. A bare `liquibase` in a new terminal will not find Java until `JAVA_HOME` points at Homebrew OpenJDK 21.

Passwords live in `.env`, copied from `.env.example` on the first `make up`. They are local-only values.
