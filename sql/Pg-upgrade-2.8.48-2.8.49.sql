CREATE TABLE IF NOT EXISTS xcontrolling_log (
    id SERIAL NOT NULL,
    trans_id INT NOT NULL,
    controlling_key VARCHAR(32) NOT NULL,
    checked boolean DEFAULT false,
    checked_timestamp TIMESTAMP NULL,
    checked_hash VARCHAR(64) NULL,
    checked_login_ref INT NULL
);

ALTER TABLE IF EXISTS xcontrolling_log
    ADD COLUMN IF NOT EXISTS checked_by_ibp_user_id BIGINT DEFAULT NULL;

UPDATE defaults SET fldvalue = '2.8.49' WHERE fldname = 'version';