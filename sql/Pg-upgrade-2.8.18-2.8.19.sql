ALTER TABLE gl ADD COLUMN onhold boolean;
ALTER TABLE gl_log ADD COLUMN onhold boolean;
ALTER TABLE gl_log_deleted ADD COLUMN onhold boolean;

UPDATE defaults SET fldvalue = '2.8.19' where fldname = 'version';

