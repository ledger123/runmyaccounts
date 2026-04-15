ALTER TABLE customer ADD COLUMN reminderstop boolean DEFAULT false;
ALTER TABLE vendor ADD COLUMN reminderstop boolean DEFAULT false;

UPDATE defaults SET fldvalue = '2.8.50' WHERE fldname = 'version';