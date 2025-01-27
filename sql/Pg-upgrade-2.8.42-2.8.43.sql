ALTER TABLE bank_account
    ADD COLUMN blink_permission_id BIGINT,
    ADD COLUMN blink_account_id TEXT;

CREATE TABLE blink_import_process(
    id SERIAL PRIMARY KEY,
    bank_account_id BIGINT REFERENCES bank_account(id),
    status TEXT NOT NULL,
    error JSONB,
    created_at TIMESTAMP NOT NULL,
    last_modified_at TIMESTAMP NOT NULL
);

CREATE TABLE blink_import_process_log(
    id SERIAL PRIMARY KEY,
    blink_import_process_id BIGINT REFERENCES blink_import_process(id),
    processed_target_id TEXT NOT NULL,
    processed_payload JSONB NOT NULL,
    error JSONB,
    banking_import_event_id BIGINT REFERENCES banking_import_event(id)
);

UPDATE defaults SET fldvalue = '2.8.43' WHERE fldname = 'version';