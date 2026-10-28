--liquibase formatted sql

--changeset praveen:003-seed-customers
--comment: Reference rows. Rollback removes these emails and leaves any other customers in place.
INSERT INTO app.customers (full_name, email) VALUES
    ('Ada Lovelace', 'ada@example.com'),
    ('Grace Hopper', 'grace@example.com');
--rollback DELETE FROM app.customers WHERE email IN ('ada@example.com', 'grace@example.com');
