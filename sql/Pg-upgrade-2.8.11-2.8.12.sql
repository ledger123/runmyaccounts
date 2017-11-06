-- ALTER TABLE invoicetax DROP COLUMN amount;
-- ALTER TABLE acc_trans DROP COLUMN tax_chart_id;
-- ALTER TABLE ar DROP COLUMN linetax;
-- ALTER TABLE ap DROP COLUMN linetax;

----

ALTER TABLE invoicetax ADD amount float;

-- AP

UPDATE invoicetax it
SET amount = (
    SELECT i.qty * i.fxsellprice * -1 
    FROM invoice i 
    WHERE i.id = it.invoice_id
)
WHERE trans_id IN (SELECT id FROM ap);

UPDATE invoicetax
SET amount = amount * (SELECT exchangerate FROM ap WHERE ap.id = invoicetax.trans_id LIMIT 1)
WHERE trans_id IN (SELECT id FROM ap);

-- AR

UPDATE invoicetax it
SET amount = (
    SELECT i.qty * i.fxsellprice
    FROM invoice i 
    WHERE i.id = it.invoice_id
)
WHERE trans_id IN (SELECT id FROM ar);

UPDATE invoicetax
SET amount = amount * (SELECT exchangerate FROM ar WHERE ar.id = invoicetax.trans_id)
WHERE trans_id IN (SELECT id FROM ar);

--

ALTER TABLE acc_trans ADD tax_chart_id INTEGER;
UPDATE acc_trans 
SET tax_chart_id = (select id from chart where accno = substr(tax,1,4)) 
WHERE tax <> '' and tax <> 'auto';

--

ALTER TABLE ar ADD linetax BOOLEAN DEFAULT false;
UPDATE ar SET linetax = '1' WHERE NOT invoice AND id IN (
    SELECT DISTINCT trans_id FROM acc_trans WHERE tax <> ''
);

--

ALTER TABLE ap ADD linetax BOOLEAN DEFAULT false;
UPDATE ap SET linetax = '1' WHERE NOT invoice AND id IN (
    SELECT DISTINCT trans_id FROM acc_trans WHERE tax <> ''
);


UPDATE acc_trans SET taxamount = amount * (SELECT rate FROM tax WHERE tax.chart_id = acc_trans.tax_chart_id AND tax.validto IS NULL LIMIT 1)
WHERE taxamount <> 0
AND trans_id IN (SELECT id FROM ap);

UPDATE acc_trans SET taxamount = ROUND(taxamount::numeric, 2) WHERE taxamount <> 0;

--
update defaults set fldvalue = '2.8.12' where fldname = 'version';


