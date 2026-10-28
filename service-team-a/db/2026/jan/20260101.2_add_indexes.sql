--liquibase formatted sql

--changeset service-team-a:20260101.2
--comment: Index users by name. The unique email constraint already has its own index.
CREATE INDEX users_full_name_idx ON app.users (full_name);
--rollback DROP INDEX app.users_full_name_idx;
