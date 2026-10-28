--liquibase formatted sql

--changeset service-team-b:20260101.1
--comment: Create orders. This changelog does not depend on service-team-a.
CREATE TABLE app.orders (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_email varchar(255) NOT NULL,
    amount_cents integer NOT NULL CHECK (amount_cents >= 0),
    created_at timestamptz NOT NULL DEFAULT now()
);
--rollback DROP TABLE app.orders;
