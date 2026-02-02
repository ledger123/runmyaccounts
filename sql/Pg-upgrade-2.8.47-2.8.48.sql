-- Add address number fields to address table
ALTER TABLE address ADD COLUMN address1_no varchar(20);
ALTER TABLE address ADD COLUMN address2_no varchar(20);

-- Update version
UPDATE defaults SET fldvalue = '2.8.48' WHERE fldname = 'version';

