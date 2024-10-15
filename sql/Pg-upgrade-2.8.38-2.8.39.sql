ALTER TABLE IF EXISTS vat_settlement
    ADD COLUMN meldecenter_data JSON;
    
UPDATE defaults SET fldvalue = '2.8.39' WHERE fldname = 'version';