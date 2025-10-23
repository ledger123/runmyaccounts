-- ALTER TABLE customer DROP CONSTRAINT IF EXISTS fk_customer_payment_discount_accno;
-- ALTER TABLE vendor DROP CONSTRAINT IF EXISTS fk_vendor_payment_discount_accno;
-- ALTER TABLE customer DROP COLUMN IF EXISTS payment_discount_accno_id;
-- ALTER TABLE customer DROP COLUMN IF EXISTS early_payment_discount;
-- ALTER TABLE vendor DROP COLUMN IF EXISTS payment_discount_accno_id;
-- ALTER TABLE vendor DROP COLUMN IF EXISTS early_payment_discount;

ALTER TABLE customer ADD payment_discount_accno_id integer;
ALTER TABLE customer ADD early_payment_discount numeric(5,2) default 0;

ALTER TABLE vendor ADD payment_discount_accno_id integer;
ALTER TABLE vendor ADD early_payment_discount numeric(5,2) default 0;

-- ALTER TABLE customer ADD CONSTRAINT fk_customer_payment_discount_accno FOREIGN KEY (payment_discount_accno_id) REFERENCES chart(id);
-- ALTER TABLE vendor ADD CONSTRAINT fk_vendor_payment_discount_accno FOREIGN KEY (payment_discount_accno_id) REFERENCES chart(id);

-- UPDATE defaults SET fldvalue = '2.8.45' WHERE fldname = 'version';

