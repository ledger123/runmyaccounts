ALTER TABLE yearend ADD id SERIAL;
ALTER TABLE yearend ADD PRIMARY KEY (id);

CREATE TYPE financial_year_status_enum AS ENUM ('OPEN', 'CURRENT_FINANCIAL_YEAR', 'CLOSED');

CREATE TABLE IF NOT EXISTS financial_year (
id SERIAL PRIMARY KEY,
start_date DATE,
end_date DATE,
status financial_year_status_enum,
yearend_id INT,
    CONSTRAINT fk_yearend 
    FOREIGN KEY (yearend_id) 
    REFERENCES yearend(id)
    ON DELETE SET NULL    
);

UPDATE defaults SET fldvalue = '2.8.33' where fldname = 'version';