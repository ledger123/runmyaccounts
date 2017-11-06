ALTER TABLE ar ADD COLUMN ts timestamp DEFAULT NOW();
ALTER TABLE ap ADD COLUMN ts timestamp DEFAULT NOW();
ALTER TABLE gl ADD COLUMN ts timestamp DEFAULT NOW();

--
-- CREATE OR REPLACE FUNCTION update_timestamp()   
-- RETURNS TRIGGER AS $$
-- BEGIN
--   NEW.ts = now();
--   RETURN NEW;
-- END;
-- $$ language 'plpgsql';

-- CREATE TRIGGER update_ar_timestamp BEFORE UPDATE ON ar FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
-- CREATE TRIGGER update_ap_timestamp BEFORE UPDATE ON ap FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
-- CREATE TRIGGER update_gl_timestamp BEFORE UPDATE ON gl FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
--

CREATE TABLE ar_log AS SELECT * FROM ar WHERE 1 = 2;
CREATE TABLE ap_log AS SELECT * FROM ap WHERE 1 = 2;
CREATE TABLE gl_log AS SELECT * FROM gl WHERE 1 = 2;

CREATE TABLE acc_trans_log AS SELECT * FROM acc_trans WHERE 1 = 2;
ALTER TABLE acc_trans_log ADD COLUMN ts timestamp DEFAULT NOW();

CREATE TABLE invoice_log AS SELECT * FROM invoice WHERE 1 = 2;
ALTER TABLE invoice_log ADD COLUMN ts timestamp DEFAULT NOW();

UPDATE ar SET 
    ts = (SELECT MAX(transdate) FROM audittrail a WHERE a.trans_id = ar.id)
WHERE id IN (SELECT trans_id FROM audittrail);

UPDATE ap SET 
    ts = (SELECT MAX(transdate) FROM audittrail a WHERE a.trans_id = ap.id)
WHERE id IN (SELECT trans_id FROM audittrail);

UPDATE gl SET 
    ts = (SELECT MAX(transdate) FROM audittrail a WHERE a.trans_id = gl.id)
WHERE id IN (SELECT trans_id FROM audittrail);

UPDATE acc_trans_log SET 
    ts = (SELECT MAX(transdate) FROM audittrail a WHERE a.trans_id = acc_trans_log.trans_id)
WHERE trans_id IN (SELECT trans_id FROM audittrail);

UPDATE invoice_log SET 
    ts = (SELECT MAX(transdate) FROM audittrail a WHERE a.trans_id = invoice_log.trans_id)
WHERE trans_id IN (SELECT trans_id FROM audittrail);

update defaults set fldvalue = '2.8.13' where fldname = 'version';

