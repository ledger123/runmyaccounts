CREATE TABLE vat_settlement (
                               id SERIAL PRIMARY KEY,
                               vat_form_id INT,
                               period_from DATE,
                               period_to DATE,
                               creation_date TIMESTAMP,
                               data JSON,
                               xml BYTEA
);

UPDATE defaults SET fldvalue = '2.8.27' where fldname = 'version';
