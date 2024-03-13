CREATE TYPE settlement_type_enum AS ENUM ('NORMAL_SETTLEMENT', 'CORRECTION_SETTLEMENT', 'ANNUAL_RECONCILIATION');

ALTER TABLE vat_settlement ADD COLUMN type settlement_type_enum;

UPDATE defaults SET fldvalue = '2.8.28' where fldname = 'version';
