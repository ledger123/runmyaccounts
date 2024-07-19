ALTER TABLE yearend ADD id SERIAL;

DO $$
DECLARE
    yearend_rec RECORD;
    new_id INT := 1;
BEGIN
    FOR yearend_rec IN
        SELECT transdate, id
        FROM yearend
        ORDER BY transdate ASC 
    LOOP
        UPDATE yearend
        SET id = new_id
        WHERE id = yearend_rec.id;

        new_id := new_id + 1;
    END LOOP;

    PERFORM setval('yearend_id_seq', (SELECT MAX(id) FROM yearend));
END $$;

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

INSERT INTO financial_year (start_date, end_date, yearend_id)
SELECT MIN(ac.transdate), MIN(ye.transdate), MIN(ye.id)
FROM acc_trans ac, yearend ye;

CREATE OR REPLACE FUNCTION generate_closed_fy()
RETURNS void AS $$
DECLARE
    closedYear RECORD;
BEGIN
    FOR closedYear IN
        SELECT transdate + 1 AS startDate, id + 1 AS yearendId
        FROM yearend
        WHERE id < (SELECT MAX(id) FROM yearend)
    LOOP
        INSERT INTO financial_year (start_date, yearend_id) VALUES
            (closedYear.startDate, closedYear.yearendId);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT generate_closed_fy();

UPDATE financial_year SET status = 'CLOSED' WHERE id > 0;
UPDATE financial_year 
SET end_date = (SELECT transdate FROM yearend WHERE financial_year.yearend_id = yearend.id) 
WHERE id > 0;

INSERT INTO financial_year (start_date, end_date, status)
SELECT y.transdate + 1, end_date + interval '12 month', 'CURRENT_FINANCIAL_YEAR'
FROM financial_year JOIN yearend y ON y.id = financial_year.yearend_id
WHERE y.transdate = (SELECT MAX(transdate) FROM yearend);

DROP FUNCTION generate_closed_fy();

UPDATE defaults SET fldvalue = '2.8.34' where fldname = 'version';