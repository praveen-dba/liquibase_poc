# Liquibase POC

Each team keeps a changelog for MySQL, MongoDB, and PostgreSQL. Liquibase applies the pending changesets and records them in that team and engine's own tracking table.

You run this against the MySQL, MongoDB, and PostgreSQL instances already on your machine. Jenkins calls the same `scripts/lb.sh`.

| Piece | Version |
| --- | --- |
| Liquibase Community | 5.0.4 |
| Java | 17 or newer. This Mac uses Homebrew OpenJDK 21 |
| PostgreSQL JDBC | 42.7.14 |
| MySQL Connector/J | 8.0.30 |
| MongoDB extension | liquibase-mongodb 5.0.3, mongo-java-driver 3.12.14 |

## Layout

A file in November 2026 is named `202611<day>.<sequence>_<description>.sql`. The sequence starts at `1` for that day. December uses `202612`.

```text
service-team-a/
├── liquibase.properties
└── db/
    ├── mysql/
    │   ├── liquibase.properties
    │   ├── root-changelog.yaml
    │   └── 2026/
    │       ├── nov/
    │       │   ├── 20261101.1_create_users_table.sql
    │       │   └── 20261101.2_add_indexes.sql
    │       └── dec/
    │           └── 20261201.1_update_user_schema.sql
    ├── mongodb/
    │   ├── liquibase.properties
    │   ├── root-changelog.yaml
    │   └── 2026/
    │       ├── nov/
    │       │   └── 20261101.1_create_user_profiles.json
    │       └── dec/
        │           └── 20261201.1_update_indexes.json
    └── postgres/
        ├── liquibase.properties
        ├── root-changelog.yaml
        └── 2026/
            ├── nov/
            │   └── 20261101.1_create_audit_table.sql
            └── dec/
                └── 20261201.1_add_partitions.sql
service-team-b/
├── liquibase.properties
└── db/
    ├── mysql/
    │   ├── liquibase.properties
    │   ├── root-changelog.yaml
    │   └── 2026/nov/20261101.1_create_orders_table.sql
    ├── mongodb/
    │   ├── liquibase.properties
    │   ├── root-changelog.yaml
    │   └── 2026/nov/20261101.1_create_orders_collection.json
    └── postgres/
        ├── liquibase.properties
        ├── root-changelog.yaml
        └── 2026/nov/20261101.1_create_transactions_table.sql
```

`liquibase_libs/`, `.env`, and `target/` stay on the machine that runs Liquibase. They are not part of the commit.

## Local run

Install once:

```bash
brew install openjdk@21
brew install --cask liquibase-community
cp .env.example .env   # then set the URL, username, and password for each engine you will use
make drivers
```

The database has to exist before `update`. For PostgreSQL, create the schema Liquibase will use (`app` unless you set `SCHEMA`). For MySQL, create the database of the same name. For MongoDB, the database in `MONGODB_URL` is enough.

```bash
make update-sql TEAM=service-team-a ENGINE=postgres
make update TEAM=service-team-a ENGINE=postgres
make status TEAM=service-team-a ENGINE=mysql
make history TEAM=service-team-b ENGINE=mongodb
make validate TEAM=service-team-a ENGINE=postgres
make rollback-count TEAM=service-team-b ENGINE=mysql N=1
make release-locks TEAM=service-team-a ENGINE=postgres
```

`SCHEMA` changes the MySQL database and the PostgreSQL schema together. The default is `app`.

```bash
SCHEMA=billing make update TEAM=service-team-a ENGINE=postgres
```

MongoDB ignores `SCHEMA`. The connection URL selects the database. Leave `MONGODB_USERNAME` empty when the local server has no authentication.

## Jenkins

`Jenkinsfile` takes `TEAM`, `ENGINE`, `COMMAND`, `ROLLBACK_COUNT`, and `SCHEMA`. The migrate stage runs `scripts/lb.sh`. The job must provide:

- `LIQUIBASE_COMMAND_URL`
- `LIQUIBASE_COMMAND_USERNAME`
- `LIQUIBASE_COMMAND_PASSWORD`

Those win over `.env` when both are present. The agent needs Java 17+ and Liquibase 5 on `PATH`. The first run installs the jars from `liquibase.json` into `liquibase_libs/`.

A changeset records `logicalFilePath`, so the Jenkins workspace directory is not part of the identity stored in the tracking table.

## Documents

- [What Liquibase is, and why use it](docs/01-what-is-liquibase.md)
- [Local setup and Jenkins](docs/02-postgresql-local-setup.md)
- [Tracking tables, permissions, versioning, and rollback](docs/03-how-it-works.md)
