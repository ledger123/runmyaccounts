ALTER TABLE bank_account
    ADD COLUMN blink_permission_id INT;

UPDATE defaults SET fldvalue = '2.8.43' WHERE fldname = 'version';