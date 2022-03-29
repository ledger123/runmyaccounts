ALTER TABLE chat
ALTER COLUMN message TYPE VARCHAR(1024);

UPDATE defaults SET fldvalue = '2.8.22' where fldname = 'version';