ALTER TABLE yearend ADD id SERIAL;
ALTER TABLE yearend ADD temp_id SERIAL;

DELETE FROM yearend
WHERE temp_id IN (SELECT temp_id
                  FROM yearend
                  EXCEPT (SELECT MAX(temp_id) FROM yearend GROUP BY trans_id, transdate));

DO $$ DECLARE yearend_rec RECORD; new_id INT := 1; BEGIN FOR yearend_rec IN SELECT transdate, temp_id FROM yearend ORDER BY transdate ASC, trans_id ASC LOOP UPDATE yearend SET id = new_id WHERE temp_id = yearend_rec.temp_id; new_id := new_id + 1; END LOOP; PERFORM setval('yearend_id_seq', (SELECT MAX(id) FROM yearend)); END $$;

ALTER TABLE yearend DROP COLUMN temp_id;
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

INSERT INTO financial_year (start_date, end_date, status, yearend_id)
WITH fin_year_ref AS (
    SELECT DISTINCT ye.transdate as end_date, MAX(ye.id) as yearend_id, ROW_NUMBER() OVER (ORDER BY ye.transdate) as rn
    FROM yearend ye, acc_trans ac
    GROUP BY ye.transdate
    ORDER BY ye.transdate
)
SELECT
    CASE WHEN fyr.rn = 1
         THEN (SELECT MIN(ac.transdate) FROM acc_trans ac)
         ELSE (SELECT prev.end_date + 1 FROM fin_year_ref prev WHERE prev.rn = fyr.rn - 1)
        END as start_date,
    fyr.end_date as end_date,
    'CLOSED'::financial_year_status_enum as status,
    fyr.yearend_id as yearend_id
FROM fin_year_ref fyr;

INSERT INTO financial_year (start_date, end_date, status)
SELECT fy.end_date + 1 as start_date,
       fy.end_date + interval '12 month' as end_date,
       'CURRENT_FINANCIAL_YEAR'::financial_year_status_enum as status
FROM financial_year fy
WHERE fy.id IN (SELECT last.id FROM financial_year last ORDER BY last.end_date DESC LIMIT 1);