--liquibase formatted sql

--changeset praveen:007-customer-count-fn splitStatements:false
--comment: splitStatements is false so the semicolon inside the function body is not a changeset boundary.
CREATE OR REPLACE FUNCTION app.customer_count()
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
    SELECT count(*) FROM app.customers;
$$;
--rollback DROP FUNCTION app.customer_count();
