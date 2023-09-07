ALTER TABLE tax ADD COLUMN reversecharge_id integer;

UPDATE defaults SET fldvalue = '2.8.24' where fldname = 'version';
