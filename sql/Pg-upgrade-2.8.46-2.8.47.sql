-- Customer table changes
ALTER TABLE customer ADD income_accno_id integer;

-- Vendor table changes
ALTER TABLE vendor ADD expense_accno_id integer;
ALTER TABLE vendor ADD early_payment_discount numeric(5,2);

-- ALTER TABLE customer ADD CONSTRAINT fk_customer_income_accno FOREIGN KEY (income_accno_id) REFERENCES chart(id);
-- ALTER TABLE vendor ADD CONSTRAINT fk_vendor_expense_accno FOREIGN KEY (expense_accno_id) REFERENCES chart(id);

-- UPDATE defaults SET fldvalue = '2.8.47' WHERE fldname = 'version';
