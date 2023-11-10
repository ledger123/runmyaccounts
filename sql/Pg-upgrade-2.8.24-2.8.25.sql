ALTER TABLE chart ADD curr VARCHAR(3);
ALTER TABLE tax ADD vatkey VARCHAR(5);
ALTER TABLE tax ADD formdigit INTEGER DEFAULT 0;
ALTER TABLE tax ADD validfrom DATE;

UPDATE defaults SET fldvalue = '2.8.25' where fldname = 'version';
