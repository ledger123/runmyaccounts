ALTER TABLE blink_import_process_log ADD COLUMN correlation_id VARCHAR(255);
ALTER TABLE blink_export_process_log ADD COLUMN correlation_id VARCHAR(255);

UPDATE defaults SET fldvalue = '2.8.51' WHERE fldname = 'version';