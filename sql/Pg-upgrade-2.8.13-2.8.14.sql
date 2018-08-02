CREATE TABLE ar_log_deleted AS SELECT * FROM ar WHERE 1 = 2;
CREATE TABLE ap_log_deleted AS SELECT * FROM ap WHERE 1 = 2;
CREATE TABLE gl_log_deleted AS SELECT * FROM gl WHERE 1 = 2;

CREATE TABLE acc_trans_log_deleted AS SELECT * FROM acc_trans WHERE 1 = 2;
ALTER TABLE acc_trans_log_deleted ADD COLUMN ts timestamp DEFAULT NOW();

CREATE TABLE invoice_log_deleted AS SELECT * FROM acc_trans WHERE 1 = 2;
ALTER TABLE invoice_log_deleted ADD COLUMN ts timestamp DEFAULT NOW();

UPDATE defaults SET fldvalue = '2.8.14' where fldname = 'version';

