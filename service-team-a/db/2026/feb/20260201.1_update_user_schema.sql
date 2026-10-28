--liquibase formatted sql

--changeset service-team-a:20260201.1
--comment: Add a lifecycle column. Existing rows receive the default.
ALTER TABLE app.users
    ADD COLUMN status varchar(20) NOT NULL DEFAULT 'active';
--rollback ALTER TABLE app.users DROP COLUMN status;
