# How it works on PostgreSQL

The notes below are from the first PostgreSQL run, when there was one changelog and the default tracking-table names. The current tree gives each team a MySQL changelog, a MongoDB changelog, and a PostgreSQL changelog. PostgreSQL tracking tables are now `serviceteama_postgres_databasechangelog` and `serviceteamb_postgres_databasechangelog`. Run them with `make update TEAM=service-team-a ENGINE=postgres` against the local server. The mechanics below are unchanged.

Everything below was run against `appdb` on PostgreSQL 16.11 with Liquibase Community 5.0.4. After the rollback tests, the database was updated forward again. That run was clean: 8 changesets applied, tag `v1.0.0` present, lock released.

The deployment ids below are from this machine after the rollbacks, so the later rows have newer ids than the first five.

## Where the tracking tables are

Liquibase creates them in the database it is connected to (`appdb`), in the schema named by `liquibaseSchemaName` (`liquibase`). They are not in `postgres`, and they are not in `public`.

The first `status` created both, before any application table existed:

| Relation | Owner |
| --- | --- |
| `liquibase.databasechangelog` | `liquibase_admin` |
| `liquibase.databasechangeloglock` | `liquibase_admin` |

`databasechangelog` has no primary key. Liquibase treats `(id, author, filename)` as the identity. The only index in the schema is `databasechangeloglock_pkey` on `id`.

### `databasechangelog`

| Column | Type | What it holds |
| --- | --- | --- |
| `id` | `varchar(255)` | Changeset id, for example `001-create-customers` |
| `author` | `varchar(255)` | `praveen` in this repo |
| `filename` | `varchar(255)` | Path Liquibase recorded, for example `changelog/changes/001-create-customers.sql` |
| `dateexecuted` | `timestamp` | When this database ran it |
| `orderexecuted` | `integer` | Sequence of execution. Rollback walks this backwards. |
| `exectype` | `varchar(10)` | `EXECUTED` for every row in this database |
| `md5sum` | `varchar(35)` | Checksum. Current values start with `9:` |
| `description` | `varchar(255)` | `sql` for formatted SQL, `tagDatabase` for the tag changeset |
| `comments` | `varchar(255)` | The `--comment` or YAML `comment` |
| `tag` | `varchar(255)` | `v1.0.0` on the tag changeset, empty on the others |
| `liquibase` | `varchar(20)` | `5.0.4` |
| `contexts` | `varchar(255)` | Empty for the main changelog |
| `labels` | `varchar(255)` | Empty here |
| `deployment_id` | `varchar(10)` | Same value for every changeset applied by one `update` |

On this database after the rollback exercises:

| `deployment_id` | Changesets |
| --- | --- |
| `3204390650` | `001` through `004`, including the orders index. The original `update`. |
| `3204621916` | `005-tag-v1_0_0`, applied again after an earlier rollback had removed it |
| `3204643043` | `006-create-payments` and `007-customer-count-fn`, applied again after `rollback --tag=v1.0.0` |

The id, author, and filename did not change when those changesets were applied again. The deployment id and `dateexecuted` did.

### `databasechangeloglock`

One row, `id = 1`.

| Column | After a successful command |
| --- | --- |
| `locked` | `false` |
| `lockgranted` | null |
| `lockedby` | null |

While an `update` holds the lock, `lockedby` is the hostname and IP of the machine running Liquibase, and `lockgranted` is the database clock. `list-locks` prints that row. The time shown is the database time (UTC in this container), not the laptop's local time.

`update` takes the lock when it has work to do. `status` does not. A lock left at `locked = true` does not stop `status`. It stops the next `update` that needs to run a changeset:

```text
Waiting for changelog lock....
Could not acquire change log lock.  Currently locked by manual-demo since 10/28/26, 4:26 PM
```

That check used `--changelog-lock-wait-time-in-minutes=0`. The default wait is longer. Clear a stale lock with `make release-locks` only after you know no Liquibase process is still running.

## Permissions

`liquibase_admin` is not a superuser. These are the privileges the init script actually granted, and the checks that confirmed them.

| Role | Superuser | `CREATEDB` | On `appdb` | On schema `app` | On schema `liquibase` |
| --- | --- | --- | --- | --- | --- |
| `postgres` | yes | yes | owner | superuser bypass | superuser bypass |
| `liquibase_admin` | no | no | `CONNECT`, `TEMPORARY` | owner | owner |
| `app_user` | no | no | `CONNECT` | `USAGE`, plus DML on tables and `USAGE`/`SELECT` on sequences | none |
| `liquibase_limited` | no | no | `CONNECT` | none | none |

`PUBLIC` has no `CONNECT` on `appdb`. `CREATE` on schema `public` is revoked. `liquibase_admin` does not have `CREATE` on the database.

What that means in practice:

- `liquibase_admin` created every application table, index, sequence, and the function. It owns them.
- `CREATE SCHEMA should_fail` as `liquibase_admin` failed: `permission denied for database appdb`.
- `CREATE EXTENSION pgcrypto` as `liquibase_admin` failed: `permission denied to create extension "pgcrypto"`. A changeset that needs an extension has to be run by a role that is allowed to create it, or the extension has to exist before `update`.
- `app_user` selected both customers and inserted one order. The insert worked because default privileges grant `INSERT` on future tables and `USAGE` on future sequences in schema `app`.
- `CREATE TABLE app.hacker` as `app_user` failed: `permission denied for schema app`.
- `SELECT` from `liquibase.databasechangelog` as `app_user` failed: `permission denied for schema liquibase`.
- `liquibase_limited` can connect, and cannot read `app.customers`. Running Liquibase as that user failed with `permission denied for schema liquibase`.

`app.customer_count()` has no explicit ACL (`proacl` is null). PostgreSQL grants `EXECUTE` on functions to `PUBLIC` by default, so `app_user` can call it. Revoke that if the function should not be public:

```sql
REVOKE EXECUTE ON FUNCTION app.customer_count() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.customer_count() TO app_user;
```

That revoke is not in the changelog. Add it as a new changeset if you want it enforced.

## Versioning

Liquibase does not version the database with a single number. It versions each changeset.

The identity stored for the first changeset is:

```text
changelog/changes/001-create-customers.sql::001-create-customers::praveen
```

That is filename, id, author. `history` and `status` print it that way.

The checksum is the version of the changeset body. Liquibase stores it in `md5sum` when the changeset runs. Any later edit to that body, including a comment inside the changeset, changes the checksum and `validate` refuses to continue. Fix the file back. Do not use `clear-checksums` to paper over an edit.

The deployment id is the version of one `update` invocation. All changesets in that invocation share it. After a rollback deletes rows and a later `update` inserts them again, those rows get a new deployment id. That is why `006` and `007` do not share an id with `001` on this database.

The tag is the release marker you choose. Changeset `005-tag-v1_0_0` writes `v1.0.0` into the `tag` column. It is how `rollback --tag=v1.0.0` knows where to stop.

Contexts are a filter, not a version. `changelog/demos/context-demo.sql` is marked `context:dev`.

- `update --contexts=prod` did not create `app.dev_notes`. The summary was `Run: 0`, `Filtered out: 1`, `Context mismatch: 1`.
- `update --contexts=dev` created the table.
- With no context filter, a changeset that has a context still runs. A filter is what excludes it.

Adding a change is always a new changeset at the end of `changelog/db.changelog-master.yaml`. The files already applied stay as they are.

`generate-changelog --schemas=app` wrote a 156-line snapshot to `target/generated-baseline.yaml` (that directory is gitignored). The generated author was the local account plus `(generated)`, and the ids were timestamps. `customers` appeared as one `createTable` that already included `status`. That snapshot is useful when you adopt Liquibase on a database you did not build with it. It is not the history of this repo, and it is not included from the master changelog.

## Rollback

Formatted SQL has no automatic rollback. If the changeset has no `--rollback`, Community 5.0.4 stops:

```text
Liquibase does not support automatic rollback generation for raw sql changes
(did you mean to specify keyword "empty" to ignore rolling back this change?)
```

The changeset stays applied. The table it created stays. `--rollback empty` tells Liquibase to forget the tracking row and leave the objects. Prefer a real undo statement. The changesets in `changelog/changes/` each have one.

Preview, then run:

```bash
./scripts/lb.sh --log-level=OFF rollback-count-sql 1
make rollback-count N=1
```

`rollback-count 1` on a fully applied database produced `DROP FUNCTION app.customer_count();`, deleted that tracking row, and left `app.payments` in place. `status` then reported 1 changeset not applied. `update` created the function again.

### Roll back to the v1.0.0 tag

The tag changeset sets `keepTagOnRollback: true`. With that set, `rollback --tag=v1.0.0` on this database:

- dropped `app.customer_count()`
- dropped `app.payments`
- left the `005-tag-v1_0_0` row, still tagged `v1.0.0`
- left customers, the status column, orders, the seed rows, and the order inserted by `app_user`

`status` then listed two pending changesets, `006` and `007`. `update` applied those two and reported `Previously run: 6`.

Without `keepTagOnRollback`, the same command also deleted the tag row. That was tested before the flag was turned on: `status` afterwards listed the tag changeset as pending too. Liquibase 5's default is to remove a `tagDatabase` row on rollback. The `tag` command behaves differently: it writes the tag onto the latest existing row, and rollback to that tag does not remove that row.

The `tag` command was checked with a throwaway table, `app.after_cli_tag`. Rollback to `cli-marker` dropped that table and kept the `007-customer-count-fn` row. The demo then cleared `cli-marker` so the committed changelog is the only marker left. The remaining tag is `v1.0.0`.

An unknown tag fails before it changes anything:

```text
Could not find tag 'does-not-exist' in the database
```

`rollback-one-changeset` is not a command in Community 5.0.4. The CLI rejected it as an unexpected argument. To undo a single changeset it has to be the most recent one (`rollback-count 1`), or you roll back to a tag and apply again what you still want.

`rollback-to-date` is installed. It was not needed for these checks. `rollback-sql` and `rollback-count-sql` are the preview commands. `update-testing-rollback` is also installed: it applies pending changesets, rolls them back, and applies them again, to prove the rollback statements work.

## When a changeset fails

`changelog/demos/failing-changeset.sql` creates a table and then inserts into `app.does_not_exist`. Liquibase reported:

```text
Migration failed for changeset changelog/demos/failing-changeset.sql::demo-fail-mid-changeset::praveen:
     Reason: ERROR: relation "app.does_not_exist" does not exist
```

The summary was `Run: 0`. The lock was released. `app.should_not_exist` was not left behind, and no tracking row was inserted. PostgreSQL had rolled the changeset's transaction back, so the `CREATE TABLE` went with the failed `INSERT`. The next `update` will try the changeset again. Fix the SQL first.

The same two statements with `runInTransaction:false` left `app.partial_apply_demo` in place and still wrote no tracking row. The demo dropped that table afterwards. Leave the default transaction on unless you have a statement PostgreSQL refuses to run inside a transaction.

A changeset that fails does not block later changesets forever. It blocks this `update`. Nothing after it in that run is applied. Fix the changeset, or replace it with a new one if it has never been recorded, and run `update` again.
