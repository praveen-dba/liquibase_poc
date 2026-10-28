# Local setup

Liquibase Community 5.0.4 runs on the machine that applies the changelog. It connects to MySQL, MongoDB, or PostgreSQL that is already running. Jenkins uses the same script and the same properties files.

Homebrew's `liquibase` formula is 4.33.0. Community 5 is the cask `liquibase-community`.

## 1. Java and Liquibase

Liquibase 5 requires Java 17 or newer.

```bash
brew install openjdk@21
brew install --cask liquibase-community
```

OpenJDK 21 is keg-only on this Mac. `scripts/lb.sh` sets `JAVA_HOME` to the Homebrew OpenJDK 21 home when `JAVA_HOME` is empty and that install exists. A Jenkins agent that already has Java 17+ on `PATH` can leave `JAVA_HOME` to the agent.

```bash
liquibase --version
```

## 2. Drivers

Liquibase 5 does not ship database drivers. `liquibase.json` pins:

| Package | Version |
| --- | --- |
| postgresql | 42.7.14 |
| mysql | 8.0.30 |
| mongodb | 3.12.14 |
| liquibase-mongodb | 5.0.3 |

```bash
make drivers
```

That runs `lpm install` when a jar is missing and writes the jars to `liquibase_libs/`. Liquibase loads that directory when the working directory is the repo root. `scripts/lb.sh` changes to the repo root before it starts Liquibase, so a Jenkins step can call the script from any directory inside the workspace.

## 3. Connection

Copy `.env.example` to `.env` and set the URL, username, and password for each engine you will run. `.env` is gitignored.

| Engine | Variable | What it points at |
| --- | --- | --- |
| PostgreSQL | `POSTGRES_URL` | JDBC database, for example `jdbc:postgresql://localhost:5432/app` |
| MySQL | `MYSQL_URL` | JDBC database, for example `jdbc:mysql://localhost:3306/app` |
| MongoDB | `MONGODB_URL` | Database in the URL, for example `mongodb://localhost:27017/app` |

Jenkins leaves `.env` unused. The job exports `LIQUIBASE_COMMAND_URL`, `LIQUIBASE_COMMAND_USERNAME`, and `LIQUIBASE_COMMAND_PASSWORD` for the one engine that build is deploying. Those values override `.env`.

Create the target before the first `update`:

```sql
-- PostgreSQL, connected to the database in POSTGRES_URL
CREATE SCHEMA IF NOT EXISTS app;

-- MySQL
CREATE DATABASE IF NOT EXISTS app;
```

MongoDB creates the database named in the URL on the first write. Leave `MONGODB_USERNAME` empty when that server has no authentication.

`SCHEMA` defaults to `app`. For PostgreSQL it is the schema. For MySQL it is the database, and it should match the database in `MYSQL_URL`. Pass `SCHEMA=billing` on the make command or as the Jenkins parameter when the name differs. MongoDB ignores it.

## 4. Apply one engine

```bash
make update-sql TEAM=service-team-a ENGINE=postgres
make update TEAM=service-team-a ENGINE=postgres
make history TEAM=service-team-a ENGINE=postgres
```

`ENGINE` is `mysql`, `postgres`, or `mongodb`. `TEAM` is `service-team-a` or `service-team-b`. The script passes that engine's `liquibase.properties` and an absolute `--search-path`, so the changelog resolves the same way on a laptop and on a Jenkins agent.

MongoDB `update-sql` needs the server running. The Community extension reads collection metadata before it prints the statements. `validate` still checks the JSON without applying it. MySQL and PostgreSQL `update-sql` can run against Liquibase's offline URL.

A file in November 2026 is named `202611<day>.<sequence>_<description>.sql`. A second change on the same day uses `.2`. December uses `202612`.

| Team | Engine | File | Id |
| --- | --- | --- | --- |
| A | mysql | `2026/nov/20261101.1_create_users_table.sql` | `20261101.1` |
| A | mysql | `2026/nov/20261101.2_add_indexes.sql` | `20261101.2` |
| A | mysql | `2026/dec/20261201.1_update_user_schema.sql` | `20261201.1` |
| A | mongodb | `2026/nov/20261101.1_create_user_profiles.json` | `20261101.1` |
| A | mongodb | `2026/dec/20261201.1_update_indexes.json` | `20261201.1` |
| A | postgres | `2026/nov/20261101.1_create_audit_table.sql` | `20261101.1` |
| A | postgres | `2026/dec/20261201.1_add_partitions.sql` | `20261201.1` |
| B | mysql | `2026/nov/20261101.1_create_orders_table.sql` | `20261101.1` |
| B | mongodb | `2026/nov/20261101.1_create_orders_collection.json` | `20261101.1` |
| B | postgres | `2026/nov/20261101.1_create_transactions_table.sql` | `20261101.1` |

Each changeset sets `logicalFilePath` to its path from the repo root. Liquibase stores that path. A different checkout directory in Jenkins does not make the changeset look new.

## 5. Add the next changeset

1. Add a file under that team's engine and month, for example `service-team-a/db/postgres/2026/dec/20261215.1_add_user_phone.sql`. Formatted SQL starts with `--liquibase formatted sql`. A MongoDB changeset is a JSON changelog. The Community MongoDB extension parses JSON.
2. Give it a new id, `20261215.1`, and the same `logicalFilePath` as the file's path from the repo root. Put the author as `service-team-a` or `service-team-b`.
3. Write the change, a comment, and a rollback. In SQL, qualify objects with `${schemaName}`.
4. Include the file at the bottom of that engine's `root-changelog.yaml`.
5. Run `make update-sql TEAM=service-team-a ENGINE=postgres`, read it, then `make update`.

Do not edit a changeset that has already been applied. Do not rename or move the file. `logicalFilePath` is part of the identity stored in that engine's tracking table. Do not reorder includes.

## 6. Jenkins

`Jenkinsfile` parameters are `TEAM`, `ENGINE`, `COMMAND`, `ROLLBACK_COUNT`, and `SCHEMA`. `COMMAND` is one of `validate`, `status`, `update-sql`, `update`, `history`, `release-locks`, or `rollback-count`.

The migrate stage checks that `LIQUIBASE_COMMAND_URL` is set, then runs `./scripts/lb.sh`. Bind the URL, username, and password from Jenkins credentials on the job. Point the URL at the database for the selected engine. The properties files in git hold the changelog path and the tracking-table names, so the job does not edit them.

Tracking tables for PostgreSQL:

| Team | Changelog | Lock |
| --- | --- | --- |
| A | `serviceteama_postgres_databasechangelog` | `serviceteama_postgres_databasechangelock` |
| B | `serviceteamb_postgres_databasechangelog` | `serviceteamb_postgres_databasechangelock` |

MySQL uses `serviceteama_mysql_databasechangelog` and `serviceteamb_mysql_databasechangelog`. MongoDB uses `serviceteama_mongodb_databasechangelog` and `serviceteamb_mongodb_databasechangelog` as collection names in the database from the URL.

`db/inspect/changelog.sql` lists the PostgreSQL tracking tables. Run it with the local `psql` against the database in `POSTGRES_URL`.
