CREATE TABLE ar_log AS SELECT * FROM ar WHERE 1 = 2;
ALTER TABLE ar_log ADD COLUMN ts timestamp DEFAULT NOW();

CREATE TABLE ap_log AS SELECT * FROM ap WHERE 1 = 2;
ALTER TABLE ap_log ADD COLUMN ts timestamp DEFAULT NOW();

CREATE TABLE acc_trans_log AS SELECT * FROM acc_trans WHERE 1 = 2;
ALTER TABLE acc_trans_log ADD COLUMN ts timestamp DEFAULT NOW();

