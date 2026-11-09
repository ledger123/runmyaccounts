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
                my ($t1, $t2) = $query =~                 /(ALTER TABLE\s+(\w+))|(UPDATE\s+(\w+))|(CREATE TABLE IF NOT EXISTS\s+(\w+))/i;
                                my $table = $2 || $4 || $6 || 'unknown';

                print "[OK] Database: $db | Table: $table updated\n";
            }
        }

        $dbh->disconnect();
    }
}

update_db(
    q{
CREATE TABLE IF NOT EXISTS xabschluss (
    id serial NOT NULL,
    name text NOT NULL,
    period_from date NOT NULL,
    period_to date NOT NULL,
    last_updated timestamp NULL DEFAULT now(),
    last_booked timestamp NULL,
    xml text NOT NULL
);
},

    q{
CREATE TABLE IF NOT EXISTS xabschluss_history (
    abschluss_ref int NOT NULL,
    last_updated timestamp NULL DEFAULT now(),
    xml text NOT NULL
);
},

    q{
ALTER TABLE xabschluss
    ALTER COLUMN "xml" DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS "data" jsonb,
    ADD COLUMN IF NOT EXISTS "status" TEXT DEFAULT 'NEW';
},

    q{
ALTER TABLE xabschluss_history
    ALTER COLUMN "xml" DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS "data" jsonb;
},

    q{
UPDATE defaults SET fldvalue = '2.8.52' WHERE fldname = 'version';
},
);

$dbh->disconnect();