ALTER TABLE banking_import_event
    ADD COLUMN delegated_to TEXT;

UPDATE defaults SET fldvalue = '2.8.44' WHERE fldname = 'version';