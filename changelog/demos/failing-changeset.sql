--liquibase formatted sql

--changeset praveen:demo-fail-mid-changeset
--comment: The INSERT names a table that does not exist. The changeset runs in one transaction, so the CREATE is rolled back with it.
CREATE TABLE app.should_not_exist (
    id bigint PRIMARY KEY
);
INSERT INTO app.does_not_exist (id) VALUES (1);
--rollback DROP TABLE IF EXISTS app.should_not_exist;
