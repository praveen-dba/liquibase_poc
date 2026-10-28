--liquibase formatted sql

--changeset praveen:004-add-customer-status
--comment: Existing rows receive the default. On PostgreSQL 11+ a constant default does not rewrite the table.
ALTER TABLE app.customers
    ADD COLUMN status varchar(20) NOT NULL DEFAULT 'active';
--rollback ALTER TABLE app.customers DROP COLUMN status;
