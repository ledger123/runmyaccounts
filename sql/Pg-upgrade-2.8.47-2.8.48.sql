CREATE TABLE IF NOT EXISTS xcontrolling_log (
    id SERIAL NOT NULL,
    trans_id INT NOT NULL,
    controlling_key VARCHAR(32) NOT NULL,
    checked boolean DEFAULT false,
    checked_timestamp TIMESTAMP NULL,
    checked_hash VARCHAR(64) NULL,
    checked_login_ref INT NULL
);