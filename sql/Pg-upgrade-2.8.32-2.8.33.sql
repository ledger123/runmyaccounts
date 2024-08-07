ALTER TABLE IF EXISTS bank_account
    ADD PRIMARY KEY (id);

CREATE TABLE IF NOT EXISTS banking_import_event (
    id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    status TEXT NOT NULL,
    bank_account_id INT REFERENCES bank_account (id),
    imported_iban TEXT,
    imported_currency TEXT,
    imported_owner TEXT,
    total_credit DOUBLE PRECISION NOT NULL,
    total_debit DOUBLE PRECISION NOT NULL,
    transactions_count INT NOT NULL,
    imported_when TIMESTAMP NOT NULL,
    source_type TEXT NOT NULL,
    is_manual BOOLEAN NOT NULL,
    filename TEXT,
    file_content TEXT
);

CREATE TABLE IF NOT EXISTS imported_balance (
    id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    banking_import_event_id INT REFERENCES banking_import_event (id) NOT NULL,
    balance_type TEXT NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    balance_currency TEXT NOT NULL,
    credit_debit TEXT NOT NULL,
    date DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS imported_transaction (
    id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    parent_imported_transaction_id INT REFERENCES imported_transaction (id),
    banking_import_event_id INT REFERENCES banking_import_event (id) NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    currency TEXT NOT NULL,
    credit_debit TEXT NOT NULL,
    booking_date DATE NOT NULL,
    status TEXT NOT NULL,
    reversal_indicator BOOLEAN,
    transaction_ref TEXT,
    bank_domain_code TEXT,
    bank_family_code TEXT,
    bank_sub_family_code TEXT,
    transaction_text TEXT,
    origin_amount DOUBLE PRECISION,
    origin_currency VARCHAR(3),
    exchange_rate DOUBLE PRECISION,
    related_party_name TEXT,
    related_party_address JSONB,
    end_to_end_id TEXT,
    purpose TEXT,
    remittance_ref TEXT,
    remittance_type TEXT,
    hashcode INT NOT NULL
);

ALTER TABLE acc_trans ADD COLUMN lineamount NUMERIC(12,2) DEFAULT 0;

ALTER TABLE acc_trans_log ADD COLUMN lineamount NUMERIC(12,2) DEFAULT 0;

ALTER TABLE acc_trans_log_deleted ADD COLUMN lineamount NUMERIC(12,2) DEFAULT 0;

UPDATE defaults SET fldvalue = '2.8.33' where fldname = 'version';