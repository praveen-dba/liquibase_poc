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

`liquibase.properties` holds the values that are safe to commit:

```properties
changeLogFile=changelog/db.changelog-master.yaml
searchPath=.
liquibaseSchemaName=liquibase
defaultSchemaName=app
logLevel=INFO
liquibase.showBanner=false
```

`scripts/common.sh` adds the connection from `.env`:

```text
jdbc:postgresql://localhost:5432/appdb
username liquibase_admin
```

Do not export `LIQUIBASE_USERNAME` or `LIQUIBASE_PASSWORD`. Liquibase 5 warns about unknown `LIQUIBASE_*` variables. The script uses `LIQUIBASE_COMMAND_USERNAME` and `LIQUIBASE_COMMAND_PASSWORD`. The `.env` keys are `MIGRATION_USERNAME` and `MIGRATION_PASSWORD`.

`liquibaseSchemaName` puts the tracking tables in schema `liquibase`. `defaultSchemaName` is where unqualified structured changes go. The SQL changesets in this repo still qualify every name with `app.`.

## 6. Apply the changelog

```bash
make status
make update-sql
make update
make history
```

`status` before the first update listed 8 pending changesets and created the two tracking tables. `update` then ran all 8:

```text
UPDATE SUMMARY
Run:                          8
Previously run:               0
Filtered out:                 0
Total change sets:            8
Liquibase: Update has been successful. Rows affected: 2
```

`Rows affected: 2` is the seed insert, not the DDL. The deployment id of that first run was `3204390650`. A later `update`, with nothing new, printed `Database is up to date, no changesets to execute` and `Run: 0`.

The changesets, in order:

| Order | Id | What it does |
| --- | --- | --- |
| 1 | `001-create-customers` | `app.customers` |
| 2 | `002-create-orders` | `app.orders`, with a foreign key to customers |
| 3 | `002b-orders-customer-idx` | index on `app.orders(customer_id)` |
| 4 | `003-seed-customers` | Ada Lovelace and Grace Hopper |
| 5 | `004-add-customer-status` | `status varchar(20) NOT NULL DEFAULT 'active'` |
| 6 | `005-tag-v1_0_0` | tag `v1.0.0`, with `keepTagOnRollback: true` |
| 7 | `006-create-payments` | `app.payments` |
| 8 | `007-customer-count-fn` | function `app.customer_count()`, `splitStatements:false` |

PostgreSQL does not index the referencing column of a foreign key, so the index is its own changeset. The function body contains a semicolon, so that changeset sets `splitStatements:false`. Without that, Liquibase would split the function on the semicolon and send an incomplete statement.

## 7. Add the next changeset

1. Add `changelog/changes/008-something.sql`. The first line must be `--liquibase formatted sql`.
2. Give it a new id. Do not reuse an id in the same file with the same author.
3. Write the SQL, a `--comment`, and a `--rollback`.
4. Include the file at the bottom of `changelog/db.changelog-master.yaml`.
5. Run `make update-sql`, read it, then `make update`.

Do not edit a changeset that has already been applied. Do not rename or move the file. The path is part of the identity stored in `databasechangelog`. Do not reorder includes.

Example shape:

```sql
--liquibase formatted sql

--changeset praveen:008-example
--comment: Why this change exists.
ALTER TABLE app.customers
    ADD COLUMN phone varchar(30);
--rollback ALTER TABLE app.customers DROP COLUMN phone;
```

## 8. Look at the result

```bash
./scripts/psql.sh super -f /db/inspect/changelog.sql
./scripts/psql.sh app -c "SELECT id, full_name, status FROM app.customers;"
```

`app_user` can select and insert. This session inserted one order as `app_user` (`amount_cents` 2500 for Ada). That row is application data. It is not a changeset.

```bash
./scripts/psql.sh app -c "CREATE TABLE app.hacker (id int);"
```

That fails with `permission denied for schema app`.

## 9. Side cases

`make demos` runs the cases that are not part of the main changelog: a changeset that fails, a changeset with no rollback, a `context:dev` changeset, a checksum mismatch, the `tag` command, and a stuck lock. It puts the main changelog back the way it found it. Run it only when `make status` says the main changelog is up to date.
