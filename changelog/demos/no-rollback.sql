--liquibase formatted sql

--changeset praveen:demo-no-rollback
--comment: No rollback block. A later rollback-count stops on this changeset.
CREATE TABLE app.no_rollback_demo (
    id bigint PRIMARY KEY,
    note text NOT NULL
);
