--liquibase formatted sql

--changeset service-team-a:20261201.1 logicalFilePath:service-team-a/db/mysql/2026/dec/20261201.1_update_user_schema.sql
--comment: Add a lifecycle column. Existing rows receive the default.
ALTER TABLE ${schemaName}.users
    ADD COLUMN status varchar(20) NOT NULL DEFAULT 'active';
--rollback ALTER TABLE ${schemaName}.users DROP COLUMN status;
