CREATE TABLE IF NOT EXISTS banking_export_event
(
    id                   SERIAL PRIMARY KEY,
    status               TEXT                             NOT NULL,
    bank_account_id      INT REFERENCES bank_account (id) NOT NULL,
    source_type          TEXT                             NOT NULL,
    exported_when        TIMESTAMP                        NOT NULL,
    is_manual            BOOLEAN                          NOT NULL,
    export_message_id    TEXT                             NOT NULL,
    export_submission_id TEXT
);

CREATE TABLE IF NOT EXISTS exported_payment
(
    id                      SERIAL PRIMARY KEY,
    banking_export_event_id BIGINT REFERENCES banking_export_event (id) NOT NULL,
    rma_payment_id          INT,
    payload                 JSONB                                       NOT NULL,
    export_instruction_id   TEXT                                        NOT NULL
);

CREATE TABLE blink_export_process
(
    id               SERIAL PRIMARY KEY,
    bank_account_id  INT REFERENCES bank_account (id) NOT NULL,
    process_type     TEXT                             NOT NULL,
    status           TEXT                             NOT NULL,
    error            JSONB,
    created_at       TIMESTAMP                        NOT NULL,
    last_modified_at TIMESTAMP
);

CREATE TABLE blink_export_process_log
(
    id                      SERIAL PRIMARY KEY,
    blink_export_process_id BIGINT REFERENCES blink_export_process (id) NOT NULL,
    processed_target_id     TEXT                                        NOT NULL,
    processed_payload       JSONB                                       NOT NULL,
    error                   JSONB,
    banking_export_event_id BIGINT REFERENCES banking_export_event (id)
);


UPDATE defaults SET fldvalue = '2.8.45' WHERE fldname = 'version';