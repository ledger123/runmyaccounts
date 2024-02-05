CREATE TABLE vat_settlement (
                               id SERIAL PRIMARY KEY,
                               vatFormId INT,
                               periodFrom DATE,
                               periodTo DATE,
                               creationDate DATE,
                               data JSON,
                               xml BYTEA
);

UPDATE defaults SET fldvalue = '2.8.27' where fldname = 'version';
