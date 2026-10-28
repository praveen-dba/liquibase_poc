\pset pager off
\echo
\echo == database version and current user ==
SELECT current_user, current_database(), version();

\echo
\echo == roles ==
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolcanlogin, rolreplication
FROM pg_roles
WHERE rolname IN ('postgres', 'liquibase_admin', 'app_user', 'liquibase_limited')
ORDER BY rolname;

\echo
\echo == database privileges ==
SELECT datname, pg_catalog.pg_get_userbyid(datdba) AS owner, datacl
FROM pg_database
WHERE datname = current_database();

\echo
\echo == schema owner and ACLs ==
SELECT n.nspname AS schema,
       pg_catalog.pg_get_userbyid(n.nspowner) AS owner,
       n.nspacl AS acl
FROM pg_namespace n
WHERE n.nspname IN ('app', 'liquibase', 'public')
ORDER BY n.nspname;

\echo
\echo == default privileges granted by liquibase_admin ==
SELECT pg_catalog.pg_get_userbyid(d.defaclrole) AS grantor,
       n.nspname AS schema,
       d.defaclobjtype AS object_type,
       d.defaclacl AS acl
FROM pg_default_acl d
LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
ORDER BY grantor, schema, object_type;
