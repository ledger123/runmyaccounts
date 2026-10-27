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

# Covering index supporting the General Ledger transactions report
# (SL/GL.pm transactions) when a date filter is active. The date filter adds
# "ac.transdate >= ... / <= ..." to the WHERE clause, which forces the
# otherwise header-only page/count queries to join acc_trans and GROUP BY the
# transaction id. The composite (transdate, trans_id) lets Postgres satisfy
# that filter+group with an index-only scan instead of scanning acc_trans.
update_db(
    q{
CREATE INDEX IF NOT EXISTS acc_trans_transdate_trans_id_key ON acc_trans (transdate, trans_id);
},
);

$dbh->disconnect();
