--liquibase formatted sql

--changeset service-team-b:20261101.1 logicalFilePath:service-team-b/db/postgres/2026/nov/20261101.1_create_transactions_table.sql
--comment: Create transactions. This changelog does not depend on service-team-a.
CREATE TABLE ${schemaName}.transactions (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    reference_code varchar(64) NOT NULL,
    amount_cents integer NOT NULL CHECK (amount_cents >= 0),
    created_at timestamptz NOT NULL DEFAULT now()
);
--rollback DROP TABLE ${schemaName}.transactions;
