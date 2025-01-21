ALTER TABLE bank_account
    ADD COLUMN blink_permission_id BIGINT,
    ADD COLUMN blink_account_id TEXT;

UPDATE defaults SET fldvalue = '2.8.43' WHERE fldname = 'version';