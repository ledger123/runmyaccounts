ALTER TABLE IF EXISTS imported_transaction
    ADD COLUMN excluded BOOLEAN NOT NULL DEFAULT FALSE;


UPDATE defaults SET fldvalue = '2.8.35' where fldname = 'version';