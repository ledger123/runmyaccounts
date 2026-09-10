#!/usr/bin/perl

use strict;
use warnings;
use DBI;

# Integration
my $dbHost   = "192.168.8.17";
# Production
#my $dbHost   = "192.168.9.20";
my $driver   = "Pg";
my $database = "einzelfirma";
my $dsn      = "DBI:$driver:dbname=$database;host=$dbHost";
my $userid   = "sql-ledger";
my $password = "";

my $dbh = DBI->connect( $dsn, $userid, $password, { RaiseError => 1 } )
  or die $DBI::errstr;

sub update_db {
    my @queries = @_;

    my $dbs = $dbh->selectcol_arrayref(
        "SELECT datname FROM pg_database WHERE datistemplate = false;"
    );

    for my $db (@$dbs) {
        my $database_dsn = "DBI:$driver:dbname=$db;host=$dbHost";
        my $dbh = DBI->connect(
            $database_dsn,
            $userid,
            $password,
            { RaiseError => 0, PrintError => 0 }
        );

        if ( !$dbh ) {
            warn "[ERROR] Failed to connect to database '$db'. Error: $DBI::errstr\n";
            next;
        }

        for my $query (@queries) {
            my $rv = $dbh->do($query);

            if ( !defined $rv ) {
                warn "[ERROR] Database: $db | Query failed: $DBI::errstr\n";
            } else {
                my ($t1, $t2) = $query =~ /(ALTER TABLE\s+(\w+))|(UPDATE\s+(\w+))/i;
                my $table = $2 || $4 || 'unknown';

                print "[OK] Database: $db | Table: $table updated\n";
            }
        }

        $dbh->disconnect();
    }
}

update_db(
    q{
ALTER TABLE address
    ADD COLUMN IF NOT EXISTS street_name varchar(70),
    ADD COLUMN IF NOT EXISTS building_number varchar(16);
},

    q{
ALTER TABLE employee
    ADD COLUMN IF NOT EXISTS street_name varchar(70),
    ADD COLUMN IF NOT EXISTS building_number varchar(16);
},

    q{
ALTER TABLE shipto
    ADD COLUMN IF NOT EXISTS shiptostreet_name varchar(70),
    ADD COLUMN IF NOT EXISTS shiptobuilding_number varchar(16);
},

    q{
CREATE OR REPLACE FUNCTION pg_temp.split_addressline(line text)
RETURNS TABLE(street_name varchar(70), building_number varchar(16)) AS $$
DECLARE
trimmed text;
    tokens  text[];
    i       int;
    rest    text[];
BEGIN
    IF line IS NULL THEN
        RETURN QUERY SELECT NULL::varchar(70), NULL::varchar(16);
RETURN;
END IF;

    trimmed := btrim(regexp_replace(line, '\s+', ' ', 'g'));
    IF trimmed = '' THEN
        RETURN QUERY SELECT NULL::varchar(70), NULL::varchar(16);
RETURN;
END IF;

    tokens := string_to_array(trimmed, ' ');
FOR i IN REVERSE array_length(tokens, 1) .. 1 LOOP
        IF tokens[i] ~ '^[0-9]' THEN
            rest := tokens[1:i-1] || tokens[i+1:array_length(tokens, 1)];
RETURN QUERY SELECT
                NULLIF(array_to_string(rest, ' '), '')::varchar(70),
                left(tokens[i], 16)::varchar(16);
RETURN;
END IF;
END LOOP;

RETURN QUERY SELECT left(trimmed, 70)::varchar(70), NULL::varchar(16);
END;
$$ LANGUAGE plpgsql IMMUTABLE;
},

    q{
UPDATE address a
SET street_name     = s.street_name,
    building_number = s.building_number
    FROM (
      SELECT id, (pg_temp.split_addressline(address1)).*
        FROM address
       WHERE street_name IS NULL AND building_number IS NULL
  ) s
WHERE a.id = s.id;
},

    q{
UPDATE employee e
SET street_name     = s.street_name,
    building_number = s.building_number
    FROM (
      SELECT id, (pg_temp.split_addressline(address1)).*
        FROM employee
       WHERE street_name IS NULL AND building_number IS NULL
  ) s
WHERE e.id = s.id;
},

    q{
UPDATE shipto sh
SET shiptostreet_name     = s.street_name,
    shiptobuilding_number = s.building_number
    FROM (
      SELECT trans_id, (pg_temp.split_addressline(shiptoaddress1)).*
        FROM shipto
       WHERE shiptostreet_name IS NULL AND shiptobuilding_number IS NULL
  ) s
WHERE sh.trans_id = s.trans_id;
},

    q{
DELETE FROM defaults
WHERE fldname IN ('street_name', 'building_number');
},

    q{
INSERT INTO defaults (fldname, fldvalue)
SELECT 'street_name', s.street_name
FROM (
         SELECT (pg_temp.split_addressline(
                 (SELECT fldvalue FROM defaults WHERE fldname = 'address1' LIMIT 1)
      )).*
     ) s
WHERE s.street_name IS NOT NULL;
},

    q{
INSERT INTO defaults (fldname, fldvalue)
SELECT 'building_number', s.building_number
FROM (
         SELECT (pg_temp.split_addressline(
                 (SELECT fldvalue FROM defaults WHERE fldname = 'address1' LIMIT 1)
      )).*
     ) s
WHERE s.building_number IS NOT NULL;
},

    q{
UPDATE defaults SET fldvalue = '2.8.53' WHERE fldname = 'version';
},
);

$dbh->disconnect();