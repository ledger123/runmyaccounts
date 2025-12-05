ALTER TABLE customer ADD income_accno_id integer;

ALTER TABLE vendor ADD expense_accno_id integer;
ALTER TABLE vendor ADD early_payment_discount numeric(5,4);

UPDATE defaults SET fldvalue = '2.8.47' WHERE fldname = 'version';