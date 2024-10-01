CREATE TABLE IF NOT EXISTS imported_transaction_to_booking (
    imported_transaction_id INT NOT NULL REFERENCES imported_transaction (id),
    booking_id INT NOT NULL,
    ledger_type VARCHAR(2) NOT NULL
);

INSERT INTO imported_transaction_to_booking (imported_transaction_id, booking_id, ledger_type)
SELECT id as imported_transaction_id, booking_id, 'GL' as ledger_type
FROM imported_transaction
    WHERE booking_id IS NOT NULL;

ALTER TABLE IF EXISTS imported_transaction
    DROP COLUMN booking_id;

UPDATE defaults SET fldvalue = '2.8.38' WHERE fldname = 'version';