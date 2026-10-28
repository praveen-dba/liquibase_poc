--liquibase formatted sql

--changeset service-team-a:20261101.1 logicalFilePath:service-team-a/db/mysql/2026/nov/20261101.1_create_users_table.sql
--comment: Create the users table.
CREATE TABLE ${schemaName}.users (
    id bigint NOT NULL AUTO_INCREMENT,
    email varchar(255) NOT NULL,
    full_name varchar(100) NOT NULL,
    created_at datetime(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY users_email_key (email)
) ENGINE=InnoDB;
--rollback DROP TABLE ${schemaName}.users;
