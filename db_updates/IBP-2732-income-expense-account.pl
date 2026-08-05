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
ALTER TABLE customer
ADD payment_clearing_accno_id integer
},

    q{
ALTER TABLE vendor
ADD payment_clearing_accno_id integer
},
);

$dbh->disconnect();