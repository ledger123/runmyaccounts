CREATE TYPE financial_year_status_enum AS ENUM ('OPEN', 'CURRENT_FINANCIAL_YEAR', 'CLOSED');

CREATE TABLE IF NOT EXISTS financial_year (
id SERIAL PRIMARY KEY,
start_date DATE,
end_date DATE,
status financial_year_status_enum
);

UPDATE defaults SET fldvalue = '2.8.33' where fldname = 'version';