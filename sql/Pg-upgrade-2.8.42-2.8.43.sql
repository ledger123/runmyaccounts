ALTER TABLE bank_account
    ADD COLUMN blink_permission_id BIGINT,
    ADD COLUMN blink_account_id TEXT;

ALTER TABLE banking_import_event
    ADD COLUMN blink_import_process_id BIGINT DEFAULT NULL;

CREATE TABLE blink_import_process(
    id SERIAL PRIMARY KEY,
    bank_account_id BIGINT REFERENCES bank_account(id),
    status TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    last_modified_at TIMESTAMP NOT NULL DEFAULT NOW()
);

UPDATE defaults SET fldvalue = '2.8.43' WHERE fldname = 'version';