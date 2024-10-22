ALTER TABLE acc_trans
    ADD COLUMN imported_transaction_id INTEGER REFERENCES imported_transaction;

WITH imported_transaction_payments AS (
    SELECT imported_transaction_id, booking_id AS invoice_id, booking_part_id AS payment_id, ledger_type AS invoice_type
    FROM imported_transaction_to_booking
    WHERE ledger_type IN ('AR', 'AP') AND booking_part_id IS NOT NULL
)
UPDATE acc_trans
SET imported_transaction_id = imported_transaction_payments.imported_transaction_id
FROM imported_transaction_payments
WHERE trans_id = imported_transaction_payments.invoice_id AND id = imported_transaction_payments.payment_id;

ALTER TABLE imported_transaction_to_booking
    DROP COLUMN booking_part_id;

UPDATE defaults SET fldvalue = '2.8.41' where fldname = 'version';
