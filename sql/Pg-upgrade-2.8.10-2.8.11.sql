
-- dispatch methods table
CREATE TABLE IF NOT EXISTS dispatch (
  id int DEFAULT nextval('id'),
  description text
);

ALTER TABLE customer ADD dispatch_id INTEGER;
ALTER TABLE vendor ADD dispatch_id INTEGER;

--
update defaults set fldvalue = '2.8.11' where fldname = 'version';
