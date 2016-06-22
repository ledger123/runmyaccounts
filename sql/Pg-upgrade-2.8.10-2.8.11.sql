DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables where table_name = 'dispatch')
  THEN
    -- dispatch methods table
    CREATE TABLE dispatch (
      id int DEFAULT nextval('id'),
      description text
    );

    ALTER TABLE customer ADD dispatch_id INTEGER;
    ALTER TABLE vendor ADD dispatch_id INTEGER;
  END IF;
END
$$
;
update defaults set fldvalue = '2.8.11' where fldname = 'version';