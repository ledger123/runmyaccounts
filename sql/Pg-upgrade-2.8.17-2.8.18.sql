ALTER TABLE bank ADD qriban TEXT;
ALTER TABLE bank ADD strdbkginf TEXT;
ALTER TABLE bank ADD invdescriptionqr TEXT;

UPDATE defaults SET fldvalue = '2.8.18' where fldname = 'version';

