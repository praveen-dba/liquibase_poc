\pset pager off
\echo
\echo == team tracking tables ==
SELECT n.nspname AS schema, c.relname AS name
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND c.relname IN (
      'serviceteama_databasechangelog',
      'serviceteama_databasechangelock',
      'serviceteamb_databasechangelog',
      'serviceteamb_databasechangelock'
  )
ORDER BY 1, 2;

\echo
\echo == service team A changesets ==
SELECT format(
    'SELECT orderexecuted, id, author, filename, exectype, liquibase, deployment_id FROM %I.%I ORDER BY orderexecuted;',
    n.nspname, c.relname)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND c.relname = 'serviceteama_databasechangelog'
\gexec

\echo
\echo == service team B changesets ==
SELECT format(
    'SELECT orderexecuted, id, author, filename, exectype, liquibase, deployment_id FROM %I.%I ORDER BY orderexecuted;',
    n.nspname, c.relname)
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind = 'r'
  AND c.relname = 'serviceteamb_databasechangelog'
\gexec
