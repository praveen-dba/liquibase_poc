--liquibase formatted sql

--changeset praveen:001-create-customers
--comment: Customer master in the application schema.
CREATE TABLE app.customers (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name varchar(100) NOT NULL,
    email varchar(255) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT customers_email_key UNIQUE (email)
);
--rollback DROP TABLE app.customers;
