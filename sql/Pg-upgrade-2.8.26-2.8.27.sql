CREATE TABLE IF NOT EXISTS vat_settlement (
                               id SERIAL PRIMARY KEY,
                               vat_form_id INT,
                               period_from DATE,
                               period_to DATE,
                               creation_date TIMESTAMP,
                               data JSON,
                               xml BYTEA
);

CREATE TABLE IF NOT EXISTS booking_to_settlement (
    id SERIAL PRIMARY KEY,
    booking_id INT NOT NULL,
    settlement_id INT REFERENCES vat_settlement(id) NOT NULL
);

UPDATE defaults SET fldvalue = '2.8.27' where fldname = 'version';
