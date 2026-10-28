#!/usr/bin/env bash
# Runs once, on an empty data volume, as part of the official Postgres image entrypoint.
# Creates the migration role, the application role, and a role with CONNECT only.
set -euo pipefail

: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_DB:?POSTGRES_DB is required}"
: "${LIQUIBASE_PASSWORD:?LIQUIBASE_PASSWORD is required}"
: "${APP_PASSWORD:?APP_PASSWORD is required}"
: "${LIMITED_PASSWORD:?LIMITED_PASSWORD is required}"

psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v liquibase_password="$LIQUIBASE_PASSWORD" \
  -v app_password="$APP_PASSWORD" \
  -v limited_password="$LIMITED_PASSWORD" \
  -v database_name="$POSTGRES_DB" <<'SQL'
-- Migration role. Owns the liquibase and app schemas. Not a superuser.
CREATE ROLE liquibase_admin LOGIN PASSWORD :'liquibase_password';

-- Runtime role. DML on future app tables. No DDL.
CREATE ROLE app_user LOGIN PASSWORD :'app_password';

-- Used by the permission demo. CONNECT only.
CREATE ROLE liquibase_limited LOGIN PASSWORD :'limited_password';

CREATE SCHEMA liquibase AUTHORIZATION liquibase_admin;
CREATE SCHEMA app AUTHORIZATION liquibase_admin;

-- PostgreSQL 15+ already withholds CREATE on public from PUBLIC.
-- Revoke it explicitly so the intent is visible, and close CONNECT on this database.
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE :"database_name" FROM PUBLIC;

GRANT CONNECT, TEMPORARY ON DATABASE :"database_name" TO liquibase_admin;
GRANT CONNECT ON DATABASE :"database_name" TO app_user;
GRANT CONNECT ON DATABASE :"database_name" TO liquibase_limited;

GRANT USAGE ON SCHEMA app TO app_user;

-- Objects Liquibase creates later, as liquibase_admin, inherit these grants.
ALTER DEFAULT PRIVILEGES FOR ROLE liquibase_admin IN SCHEMA app
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

ALTER DEFAULT PRIVILEGES FOR ROLE liquibase_admin IN SCHEMA app
    GRANT USAGE, SELECT ON SEQUENCES TO app_user;

ALTER ROLE liquibase_admin SET search_path = app, liquibase;
ALTER ROLE app_user SET search_path = app;

SELECT rolname, rolsuper, rolcreatedb, rolcanlogin
FROM pg_roles
WHERE rolname IN ('liquibase_admin', 'app_user', 'liquibase_limited')
ORDER BY rolname;
SQL
