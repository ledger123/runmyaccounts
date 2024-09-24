CREATE TABLE IF NOT EXISTS imported_transaction_to_invoice (
    imported_transaction_id INT NOT NULL REFERENCES imported_transaction (id),
    invoice_id INT NOT NULL,
    invoice_type VARCHAR(2) NOT NULL,
    payment_index INT NOT NULL
);

INSERT INTO imported_transaction_to_invoice (imported_transaction_id, invoice_id, invoice_type, payment_index)
SELECT imported_transaction_id AS imported_transaction_id,
       booking_id AS invoice_id,
       ledger_type AS invoice_type,
       1 AS payment_index
FROM imported_transaction_to_booking
    WHERE ledger_type IN ('AR', 'AP');

DELETE FROM imported_transaction_to_booking
    WHERE ledger_type IN ('AR', 'AP');

ALTER TABLE imported_transaction_to_booking
    DROP COLUMN ledger_type,
    ADD CONSTRAINT imported_transaction_to_booking_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES gl (id);

UPDATE defaults SET fldvalue = '2.8.39' WHERE fldname = 'version';