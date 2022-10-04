-- Required for structured addresses modification

ALTER TABLE address
    ADD COLUMN IF NOT EXISTS post_office varchar(64),
    ADD COLUMN IF NOT EXISTS is_migrated boolean DEFAULT TRUE
;

UPDATE defaults SET fldvalue = '2.8.23' where fldname = 'version';
