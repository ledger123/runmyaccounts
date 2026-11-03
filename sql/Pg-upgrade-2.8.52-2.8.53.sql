BEGIN;

ALTER TABLE address
    ADD COLUMN IF NOT EXISTS street_name varchar(70),
    ADD COLUMN IF NOT EXISTS building_number varchar(16);

ALTER TABLE employee
    ADD COLUMN IF NOT EXISTS street_name varchar(70),
    ADD COLUMN IF NOT EXISTS building_number varchar(16);

ALTER TABLE shipto
    ADD COLUMN IF NOT EXISTS shiptostreet_name varchar(70),
    ADD COLUMN IF NOT EXISTS shiptobuilding_number varchar(16);

CREATE OR REPLACE FUNCTION pg_temp.split_addressline(line text)
RETURNS TABLE(street_name varchar(70), building_number varchar(16)) AS $$
DECLARE
    trimmed text;
    tokens text[];
    i int;
BEGIN
    trimmed := btrim(regexp_replace(line, '\s+', ' ', 'g'));
    IF trimmed IS NULL OR trimmed = '' THEN
        RETURN QUERY SELECT NULL::varchar(70), NULL::varchar(16);
        RETURN;
    END IF;

    tokens := string_to_array(trimmed, ' ');
    FOR i IN REVERSE array_length(tokens, 1) .. 1 LOOP
        IF tokens[i] ~ '^[0-9]' THEN
            RETURN QUERY SELECT
                NULLIF(array_to_string(
                    tokens[1:i-1] || tokens[i+1:array_length(tokens, 1)], ' '
                ), '')::varchar(70),
                tokens[i]::varchar(16);
            RETURN;
        END IF;
    END LOOP;

    RETURN QUERY SELECT trimmed::varchar(70), NULL::varchar(16);
END;
$$ LANGUAGE plpgsql IMMUTABLE;
-- end function

UPDATE address a
   SET street_name = s.street_name,
       building_number = s.building_number
  FROM (
      SELECT id, (pg_temp.split_addressline(address1)).*
        FROM address
       WHERE street_name IS NULL AND building_number IS NULL
  ) s
 WHERE a.id = s.id;

UPDATE employee e
   SET street_name = s.street_name,
       building_number = s.building_number
  FROM (
      SELECT id, (pg_temp.split_addressline(address1)).*
        FROM employee
       WHERE street_name IS NULL AND building_number IS NULL
  ) s
 WHERE e.id = s.id;

UPDATE shipto sh
   SET shiptostreet_name = s.street_name,
       shiptobuilding_number = s.building_number
  FROM (
      SELECT ctid AS row_id, (pg_temp.split_addressline(shiptoaddress1)).*
        FROM shipto
       WHERE shiptostreet_name IS NULL AND shiptobuilding_number IS NULL
  ) s
 WHERE sh.ctid = s.row_id;

INSERT INTO defaults (fldname, fldvalue)
SELECT v.fldname, v.fldvalue
  FROM pg_temp.split_addressline(
      COALESCE(
          (SELECT NULLIF(fldvalue, '') FROM defaults WHERE fldname = 'address1' LIMIT 1),
          split_part((SELECT fldvalue FROM defaults WHERE fldname = 'address' LIMIT 1), E'\n', 1)
      )
  ) s
 CROSS JOIN LATERAL (
     VALUES ('street_name', s.street_name), ('building_number', s.building_number)
 ) v(fldname, fldvalue)
 WHERE v.fldvalue IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM defaults WHERE fldname IN ('street_name', 'building_number')
   );

UPDATE defaults SET fldvalue = '2.8.53' WHERE fldname = 'version';

COMMIT;
