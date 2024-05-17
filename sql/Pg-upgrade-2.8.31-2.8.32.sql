ALTER TABLE acc_trans ADD COLUMN lineamount NUMERIC(12,2) DEFAULT 0;

ALTER TABLE acc_trans_log ADD COLUMN lineamount NUMERIC(12,2) DEFAULT 0;

ALTER TABLE acc_trans_log_deleted ADD COLUMN lineamount NUMERIC(12,2) DEFAULT 0;

UPDATE defaults SET fldvalue = '2.8.32' WHERE fldname = 'version';

