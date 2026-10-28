--liquibase formatted sql

--changeset service-team-a:20261101.2 logicalFilePath:service-team-a/db/mysql/2026/nov/20261101.2_add_indexes.sql
--comment: Index users by name. The unique email key already has its own index.
CREATE INDEX users_full_name_idx ON ${schemaName}.users (full_name);
--rollback DROP INDEX users_full_name_idx ON ${schemaName}.users;
