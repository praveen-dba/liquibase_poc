--liquibase formatted sql

--changeset service-team-a:20261101.1
--comment: Create the users table.
CREATE TABLE app.users (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email varchar(255) NOT NULL,
    full_name varchar(100) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT users_email_key UNIQUE (email)
);
--rollback DROP TABLE app.users;
