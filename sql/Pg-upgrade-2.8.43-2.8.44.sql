ALTER TABLE banking_import_event
    ADD COLUMN delegated_to TEXT,
    ALTER COLUMN total_credit DROP NOT NULL,
    ALTER COLUMN total_debit DROP NOT NULL,
    ALTER COLUMN transactions_count DROP NOT NULL;

UPDATE defaults SET fldvalue = '2.8.44' WHERE fldname = 'version';