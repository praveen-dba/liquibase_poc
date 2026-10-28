# PostgreSQL local setup

This is the setup that is running on this Mac. PostgreSQL is the Docker image `postgres:16.11`. Liquibase Community 5.0.4 runs on the host and connects to `localhost:5432`.

Homebrew's `postgresql@16` formula is 16.15, so it was not used. Homebrew's `liquibase` formula is 4.33.0. Community 5 is the cask `liquibase-community`.

## 1. Java and Liquibase

Liquibase 5 requires Java 17 or newer. This machine uses Homebrew OpenJDK 21.0.13.

```bash
brew install openjdk@21
brew install --cask liquibase-community
```

OpenJDK 21 is keg-only. It is not on the default `PATH`. The scripts in this repo set:

```bash
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
```

Check the install:

```bash
"$JAVA_HOME/bin/java" -version
liquibase --version
```

`liquibase --version` on this machine printed `Liquibase Version: 5.0.4` and `Java Home` under the OpenJDK 21 cellar. The first run also downloaded the Liquibase Package Manager into the Liquibase install directory.

## 2. PostgreSQL JDBC driver

Liquibase 5 does not ship database drivers. From the repo root:

```bash
/opt/homebrew/Caskroom/liquibase-community/5.0.4/lpm add postgresql
```

That installed `postgresql-42.7.14.jar` into `liquibase_libs/` and wrote `liquibase.json`. Liquibase adds every jar in `liquibase_libs/` when you run it from the repo root. There is no `driver:` property and no copy into `/usr/bin/internal/lib`.

`make up` runs `lpm install` if that jar is missing, using the version pinned in `liquibase.json`. The jar itself stays local.

## 3. PostgreSQL 16.11

Docker Desktop has to be running.

```bash
cp .env.example .env   # make up does this if .env is absent
make up
```

`make up` starts `docker-compose.yml` and waits until the health check passes. The container is `liquibase_poc_postgres`. The server log from the first boot was:

```text
starting PostgreSQL 16.11 (Debian 16.11-1.pgdg13+1) on aarch64-unknown-linux-gnu
```

Confirm it from the client inside the container:

```bash
make psql ROLE=super
```

```sql
SHOW server_version;
```

```text
16.11 (Debian 16.11-1.pgdg13+1)
```

Port `5432` on the host is published to `5432` in the container. Nothing else was listening on `5432` when this was set up. Change `POSTGRES_PORT` in `.env` if that port is taken, then recreate the container.

The data volume is `liquibase_poc_pgdata`. `make down` stops the container and keeps the volume. `make reset` deletes the volume, so the init script runs again and the tracking tables are gone.

## 4. Roles created on first boot

`db/init/01-init-roles.sh` runs once, as the `postgres` superuser, against database `appdb`. A later container start does not run it again.

| Role | Password in `.env.example` | What it is for |
| --- | --- | --- |
| `postgres` | `postgres_local_only` | Superuser. Creates roles and schemas. Not used by Liquibase. |
| `liquibase_admin` | `liquibase_local_only` | Runs Liquibase. Owns schemas `liquibase` and `app`. |
| `app_user` | `app_user_local_only` | Application runtime. DML on `app` tables only. |
| `liquibase_limited` | `limited_local_only` | Permission demo. `CONNECT` and nothing else. |

The script also:

- creates schemas `liquibase` and `app`, owned by `liquibase_admin`
- revokes `CONNECT` on `appdb` from `PUBLIC`, then grants `CONNECT` to the three roles
- grants `TEMPORARY` on `appdb` to `liquibase_admin`
- grants `USAGE` on schema `app` to `app_user`
- sets default privileges so tables and sequences later created by `liquibase_admin` in `app` are usable by `app_user`
- does **not** grant `CREATE` on the database, so `liquibase_admin` cannot create another schema

Inspect what was created:

```bash
./scripts/psql.sh super -f /db/inspect/privileges.sql
```

## 5. Liquibase connection

Each team has its own properties file. `service-team-a/liquibase.properties`:

```properties
changeLogFile=db/root-changelog.yaml
databaseChangeLogTableName=serviceteama_databasechangelog
databaseChangeLogLockTableName=serviceteama_databasechangelock
```

`service-team-b/liquibase.properties`:

```properties
changeLogFile=db/root-changelog.yaml
databaseChangeLogTableName=serviceteamb_databasechangelog
databaseChangeLogLockTableName=serviceteamb_databasechangelock
```

`scripts/lb.sh` runs from the repo root so the JDBC jar in `liquibase_libs/` is found, and passes `--defaults-file` plus `--search-path` for the team you name. The changelog path in the properties file is relative to that team directory.

`scripts/common.sh` adds the connection from `.env`:

```text
jdbc:postgresql://localhost:5432/appdb
username liquibase_admin
```

Do not export `LIQUIBASE_USERNAME` or `LIQUIBASE_PASSWORD`. Liquibase 5 warns about unknown `LIQUIBASE_*` variables. The script uses `LIQUIBASE_COMMAND_USERNAME` and `LIQUIBASE_COMMAND_PASSWORD`. The `.env` keys are `MIGRATION_USERNAME` and `MIGRATION_PASSWORD`.

The properties file does not set a schema. Liquibase creates the tracking tables in the first schema on `liquibase_admin`'s search path, which the init script sets to `app`. The SQL changesets still qualify application objects with `app.`.

## 6. Apply a team's changelog

```bash
make update TEAM=service-team-a
make update TEAM=service-team-b
make history TEAM=service-team-a
```

On a clean database, team A runs 3 changesets and team B runs 2. A later `update` for a team that is already applied prints `Database is up to date, no changesets to execute`.

Months are included in calendar order from `db/root-changelog.yaml`. A new file is not picked up just because it sits in the folder. Add an `include` for it.

A file in January 2026 is named `202601<day>.<sequence>_<description>.sql`. The sequence starts at `1` for that day. A second change on the same day is `.2`.

| Team | File | Id | What it does |
| --- | --- | --- | --- |
| A | `2026/jan/20260101.1_create_users_table.sql` | `20260101.1` | `app.users` |
| A | `2026/jan/20260101.2_add_indexes.sql` | `20260101.2` | index on `app.users (full_name)` |
| A | `2026/feb/20260201.1_update_user_schema.sql` | `20260201.1` | `status` column on `app.users` |
| B | `2026/jan/20260101.1_create_orders_table.sql` | `20260101.1` | `app.orders` |
| B | `2026/feb/20260201.1_add_payment_status.sql` | `20260201.1` | `payment_status` column on `app.orders` |

Team B does not reference team A's tables, so either changelog can be applied on its own.

## 7. Add the next changeset

1. Add a file under that team's month directory, for example `service-team-a/db/2026/mar/20260301.1_add_user_phone.sql`. The first line must be `--liquibase formatted sql`.
2. Give it a new id. Do not reuse an id in the same file with the same author.
3. Write the SQL, a `--comment`, and a `--rollback`.
4. Include the file at the bottom of that team's `db/root-changelog.yaml`.
5. Run `make update-sql TEAM=service-team-a`, read it, then `make update TEAM=service-team-a`.

Do not edit a changeset that has already been applied. Do not rename or move the file. The path is part of the identity stored in that team's changelog table. Do not reorder includes.

## 8. Look at the result

```bash
./scripts/psql.sh super -f /db/inspect/changelog.sql
```

That lists `serviceteama_databasechangelog` and `serviceteamb_databasechangelog` wherever they were created.

```bash
./scripts/psql.sh app -c "CREATE TABLE app.hacker (id int);"
```

That fails with `permission denied for schema app`.

`appdb` still contains the objects from the first single changelog, including `app.orders`. Team B cannot create `app.orders` there until you recreate the volume with `make reset`. The team files were applied on database `teamdb` in the same PostgreSQL instance.
