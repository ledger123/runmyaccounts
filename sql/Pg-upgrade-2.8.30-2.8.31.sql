ALTER TABLE tax ADD COLUMN IF NOT EXISTS inactive BOOLEAN DEFAULT false; 

UPDATE defaults SET fldvalue = '2.8.31' where fldname = 'version';
