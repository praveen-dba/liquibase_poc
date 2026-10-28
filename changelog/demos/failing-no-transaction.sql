--liquibase formatted sql

--changeset praveen:demo-fail-no-transaction runInTransaction:false
--comment: Same failure with the changeset transaction turned off. The CREATE can remain.
CREATE TABLE app.partial_apply_demo (
    id bigint PRIMARY KEY
);
INSERT INTO app.does_not_exist (id) VALUES (1);
--rollback DROP TABLE IF EXISTS app.partial_apply_demo;
