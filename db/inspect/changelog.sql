\pset pager off
\echo
\echo == relations in the liquibase and app schemas ==
SELECT n.nspname AS schema, c.relname AS name, c.relkind
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ('liquibase', 'app')
  AND c.relkind IN ('r', 'i', 'S', 'v')
ORDER BY n.nspname, c.relkind, c.relname;

\echo
\echo == DATABASECHANGELOG columns ==
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'liquibase'
  AND table_name = 'databasechangelog'
ORDER BY ordinal_position;

\echo
\echo == DATABASECHANGELOGLOCK columns ==
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'liquibase'
  AND table_name = 'databasechangeloglock'
ORDER BY ordinal_position;

\echo
\echo == executed changesets ==
SELECT orderexecuted,
       id,
       author,
       filename,
       exectype,
       md5sum,
       description,
       tag,
       liquibase,
       deployment_id,
       dateexecuted
FROM liquibase.databasechangelog
ORDER BY orderexecuted;

\echo
\echo == lock row ==
SELECT * FROM liquibase.databasechangeloglock;
