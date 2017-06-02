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
CREATE TABLE acc_trans_log AS SELECT * FROM acc_trans WHERE 1 = 2;
ALTER TABLE acc_trans_log ADD COLUMN ts timestamp DEFAULT NOW();


