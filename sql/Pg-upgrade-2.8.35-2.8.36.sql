ALTER TABLE IF EXISTS imported_transaction
    ADD COLUMN booking_id INTEGER,
    ADD COLUMN suppression TEXT;

UPDATE imported_transaction
SET suppression = 'EXCLUDED'
WHERE excluded = true;

ALTER TABLE IF EXISTS imported_transaction
    DROP COLUMN excluded;

UPDATE defaults SET fldvalue = '2.8.36' where fldname = 'version';