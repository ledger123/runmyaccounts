ALTER TABLE gl ADD COLUMN IF NOT EXISTS  onhold boolean;
ALTER TABLE gl_log ADD COLUMN IF NOT EXISTS onhold boolean;
ALTER TABLE gl_log_deleted ADD COLUMN IF NOT EXISTS onhold boolean;

UPDATE defaults SET fldvalue = '2.8.19' where fldname = 'version';

