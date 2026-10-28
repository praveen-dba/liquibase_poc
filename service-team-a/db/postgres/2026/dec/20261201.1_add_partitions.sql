--liquibase formatted sql

--changeset service-team-a:20261201.1 logicalFilePath:service-team-a/db/postgres/2026/dec/20261201.1_add_partitions.sql
--comment: Add the December partition for audit events.
CREATE TABLE ${schemaName}.audit_events_2026_12
    PARTITION OF ${schemaName}.audit_events
    FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
--rollback DROP TABLE ${schemaName}.audit_events_2026_12;
