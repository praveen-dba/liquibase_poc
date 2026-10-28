--liquibase formatted sql

--changeset praveen:demo-dev-notes context:dev
--comment: Runs when no context filter is given, and when the filter matches dev. Skipped for any other filter, such as prod.
CREATE TABLE app.dev_notes (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    note text NOT NULL
);
--rollback DROP TABLE app.dev_notes;
