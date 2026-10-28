# What Liquibase is

Liquibase is an open-source tool that applies database changes in a fixed order and records each change in the database itself. You keep the changes in git, next to the application. Liquibase connects with JDBC, reads a changelog, and runs only the changes that this database has not recorded yet.

A changelog is an ordered list of changesets. A changeset is one change, with an id, an author, and the file it lives in. Those three values are its identity. Liquibase stores that identity in a tracking table after the change succeeds. The next run skips it.

This POC uses Liquibase Community 5.0.4 against PostgreSQL 16.11. The older notes for MySQL and MongoDB were written around Liquibase 4. The workflow here is the Community 5 workflow: Java 17 or newer, the PostgreSQL driver installed with `lpm`, and a changelog we write by hand and only append to.

## What you gain

**The same changes run in the same order everywhere.** Development, test, and production each have their own database. They share one changelog. `liquibase update` applies whatever that database has not recorded yet.

**The database remembers what ran.** After a successful update, the tracking table has one row per changeset: id, author, filename, checksum, comment, the Liquibase version that ran it, and a deployment id shared by every changeset in that run. This repo gives each team its own table, `serviceteama_databasechangelog` and `serviceteamb_databasechangelog`, so the teams can share one database without sharing one history. You do not have to infer the schema version from a filename or from whoever last logged into the server.

**A second deploy is a no-op.** On this database, the first `update` ran 8 changesets. The next `update` reported `Run: 0`, `Previously run: 8`, and `Database is up to date, no changesets to execute`.

**An edited changeset is rejected.** Liquibase stores an MD5 of each changeset. Changing a changeset that has already run makes `validate` and `update` fail. On this machine, appending one comment line to `001-create-customers.sql` produced:

```text
Validation Failed:
     1 changesets check sum
          changelog/changes/001-create-customers.sql::001-create-customers::praveen
          was: 9:00f3a1e8d519d8e2649391d5813d9f70
          but is now: 9:a7bff159fc0260582c4a3d0e8c49ee3d
```

The file was restored after that check. The rule is: write a new changeset. Do not change one that has been applied.

**Two deploys cannot run at once.** Liquibase takes a row lock in `liquibase.databasechangeloglock` before it changes anything. A second `update` waits, then fails if the lock is still held. `release-locks` clears a lock left behind by a crashed run. `status` does not take the lock, so it is the wrong command for checking that.

**You can read the SQL before it runs.** `update-sql` prints the statements, including the inserts into the tracking table, and does not leave them committed. `rollback-sql` does the same for a rollback. Run those before `update` or `rollback` when the change matters.

**Rollback is written with the change.** Each formatted SQL changeset in this repo has a `--rollback` statement. Rolling back the last changeset dropped `app.customer_count()`. Rolling back to the tag `v1.0.0` dropped `app.payments` and that function, and left customers, orders, and the tag row in place.

**A failed changeset does not leave a half-built table.** PostgreSQL runs DDL inside a transaction. The demo changeset creates `app.should_not_exist` and then inserts into a table that is not there. Liquibase stopped, the create was rolled back with the insert, and no tracking row was written. The next `update` can try that changeset again.

**The migration user is not a superuser.** `liquibase_admin` owns the `app` and `liquibase` schemas and can create tables there. It cannot create a schema, and it cannot create an extension. The application role, `app_user`, can read and write the application tables and cannot create them or read the tracking tables.

## What Liquibase does not replace

Rollback undoes changesets whose rollback you wrote. It is not a backup. An `INSERT` the application did on its own stays in place unless a changeset's own rollback deletes it. During this POC, `app_user` inserted one order. Rolling back later changesets left that order where it was.

Community 5.0.4 does not have a command to roll back one changeset by id. `rollback-one-changeset` is not a command in this build. The Community commands are `rollback-count`, `rollback --tag`, and `rollback-to-date`.

`generate-changelog` can snapshot a database that already exists. It is a starting point for adoption, not the changelog you keep editing. This repo keeps the hand-written files under each team's `db/2026/` directories.

## How a run works

1. Liquibase connects as `liquibase_admin`.
2. It creates that team's changelog table and lock table if they are missing. The names come from the team's `liquibase.properties`.
3. It reads that team's `db/root-changelog.yaml` and compares it with that team's tracking table.
4. `update` locks the lock row, runs each missing changeset, inserts a tracking row in the same transaction, then releases the lock.
5. A later environment runs the same files. Changesets already recorded there are skipped. New ones at the bottom of the changelog are applied.
