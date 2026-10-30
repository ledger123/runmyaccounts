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

# Indexes supporting the AR/AP transactions report (SL/AA.pm transactions):
# the composite (transdate, id) indexes match the keyset pagination
# ORDER BY a.transdate DESC, a.id DESC and its (transdate, id) cursor, while
# address(trans_id) speeds up the per-row address_join subquery.
update_db(
    q{
CREATE INDEX IF NOT EXISTS ar_transdate_id_key ON ar (transdate, id);
},

    q{
CREATE INDEX IF NOT EXISTS ap_transdate_id_key ON ap (transdate, id);
},

    q{
CREATE INDEX IF NOT EXISTS address_trans_id_key ON address (trans_id);
},
);

$dbh->disconnect();
