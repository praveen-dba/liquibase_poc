--liquibase formatted sql

--changeset praveen:002-create-orders
--comment: Orders reference customers. PostgreSQL enforces the foreign key.
CREATE TABLE app.orders (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES app.customers (id),
    amount_cents integer NOT NULL CHECK (amount_cents >= 0),
    status varchar(20) NOT NULL DEFAULT 'pending',
    created_at timestamptz NOT NULL DEFAULT now()
);
--rollback DROP TABLE app.orders;

--changeset praveen:002b-orders-customer-idx
--comment: PostgreSQL does not index the referencing side of a foreign key.
CREATE INDEX orders_customer_id_idx ON app.orders (customer_id);
--rollback DROP INDEX app.orders_customer_id_idx;
