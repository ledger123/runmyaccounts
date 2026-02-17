ALTER TABLE customer ADD payment_clearing_accno_id integer
ALTER TABLE vendor ADD payment_clearing_accno_id integer

UPDATE defaults SET fldvalue = '2.8.48' WHERE fldname = 'version';