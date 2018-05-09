ALTER TABLE customer ALTER COLUMN name TYPE varchar(128);
ALTER TABLE vendor ALTER COLUMN name TYPE varchar(128);

UPDATE defaults SET fldvalue = '2.8.16' where fldname = 'version';

