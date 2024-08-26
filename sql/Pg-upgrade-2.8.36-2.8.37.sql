ALTER TABLE IF EXISTS bank_account
    ADD COLUMN currency VARCHAR(3);

UPDATE bank_account ba
SET currency = c.curr
FROM chart c
    WHERE ba.chart_id = c.id;

ALTER TABLE chart
    DROP COLUMN curr;

UPDATE defaults SET fldvalue = '2.8.37' WHERE fldname = 'version';