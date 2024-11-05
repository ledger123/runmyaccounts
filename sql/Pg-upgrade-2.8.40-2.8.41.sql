ALTER TABLE acc_trans
    ADD COLUMN imported_transaction_id INTEGER REFERENCES imported_transaction;

DELETE FROM imported_transaction_to_booking
    WHERE ledger_type IN ('AR', 'AP');

ALTER TABLE imported_transaction_to_booking
    DROP COLUMN IF EXISTS booking_part_id,
    ADD COLUMN IF NOT EXISTS exchange_rate DOUBLE PRECISION;

UPDATE defaults SET fldvalue = '2.8.41' where fldname = 'version';
