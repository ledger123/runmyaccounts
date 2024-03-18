ALTER TABLE booking_to_settlement ADD COLUMN type settlement_type_enum;

UPDATE defaults SET fldvalue = '2.8.29' where fldname = 'version';
