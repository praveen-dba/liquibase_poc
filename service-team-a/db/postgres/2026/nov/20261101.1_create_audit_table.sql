--liquibase formatted sql

--changeset service-team-a:20261101.1 logicalFilePath:service-team-a/db/postgres/2026/nov/20261101.1_create_audit_table.sql
--comment: Audit events, partitioned by month. November is the first partition.
CREATE TABLE ${schemaName}.audit_events (
    id bigint GENERATED ALWAYS AS IDENTITY,
    actor varchar(255) NOT NULL,
    action varchar(100) NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);

CREATE TABLE ${schemaName}.audit_events_2026_11
    PARTITION OF ${schemaName}.audit_events
    FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
--rollback DROP TABLE ${schemaName}.audit_events;
