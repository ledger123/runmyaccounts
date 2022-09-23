-- Required for structured addresses modification

ALTER TABLE address
    ADD COLUMN post_office varchar(64),
    ADD COLUMN is_migrated boolean
;

UPDATE defaults SET fldvalue = '2.8.23' where fldname = 'version';