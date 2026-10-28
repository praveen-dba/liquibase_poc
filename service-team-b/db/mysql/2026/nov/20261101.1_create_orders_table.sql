--liquibase formatted sql

--changeset service-team-b:20261101.1 logicalFilePath:service-team-b/db/mysql/2026/nov/20261101.1_create_orders_table.sql
--comment: Create orders. This changelog does not depend on service-team-a.
CREATE TABLE ${schemaName}.orders (
    id bigint NOT NULL AUTO_INCREMENT,
    user_email varchar(255) NOT NULL,
    amount_cents integer NOT NULL,
    created_at datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    CONSTRAINT orders_amount_cents_nonnegative CHECK (amount_cents >= 0)
) ENGINE=InnoDB;
--rollback DROP TABLE ${schemaName}.orders;
