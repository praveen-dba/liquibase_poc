--liquibase formatted sql

--changeset praveen:006-create-payments
--comment: Added after the v1.0.0 tag, so rollback v1.0.0 drops this table.
CREATE TABLE app.payments (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id bigint NOT NULL REFERENCES app.orders (id),
    amount_cents integer NOT NULL CHECK (amount_cents > 0),
    paid_at timestamptz NOT NULL DEFAULT now()
);
--rollback DROP TABLE app.payments;
