--liquibase formatted sql

--changeset service-team-b:V1.2
--comment: Track whether an order has been paid.
ALTER TABLE app.orders
    ADD COLUMN payment_status varchar(20) NOT NULL DEFAULT 'pending';
--rollback ALTER TABLE app.orders DROP COLUMN payment_status;
