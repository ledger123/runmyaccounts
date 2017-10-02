ALTER TABLE ar ADD COLUMN ts timestamp DEFAULT NOW();
ALTER TABLE ap ADD COLUMN ts timestamp DEFAULT NOW();
ALTER TABLE gl ADD COLUMN ts timestamp DEFAULT NOW();

CREATE TABLE ar_log AS SELECT * FROM ar WHERE 1 = 2;
CREATE TABLE ap_log AS SELECT * FROM ap WHERE 1 = 2;
CREATE TABLE gl_log AS SELECT * FROM gl WHERE 1 = 2;
CREATE TABLE acc_trans_log AS SELECT * FROM acc_trans WHERE 1 = 2;
ALTER TABLE acc_trans_log ADD COLUMN ts timestamp DEFAULT NOW();

--
update defaults set fldvalue = '2.8.13' where fldname = 'version';


