ALTER TABLE imported_transaction_to_booking
    ADD COLUMN booking_part_id INT;

UPDATE defaults SET fldvalue = '2.8.40' WHERE fldname = 'version';