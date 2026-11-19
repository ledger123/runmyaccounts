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

my $index_name = 'acc_trans_transdate_trans_id_idx';
my $table_name = 'acc_trans';

my $dbh = DBI->connect( $dsn, $userid, $password, { RaiseError => 1, PrintError => 0, AutoCommit => 1 } )
  or die $DBI::errstr;

sub create_index_concurrently {
    my ($db, $dbh_db) = @_;

    my ($tbl) = $dbh_db->selectrow_array( "SELECT to_regclass(?)", undef, $table_name );
    if ( !defined $tbl ) {
        print "[SKIP] Database: $db | table not found $table_name\n";
        return;
    }

    my ($invalid) = $dbh_db->selectrow_array(
        "SELECT 1 FROM pg_index WHERE indexrelid = to_regclass(?) AND NOT indisvalid",
        undef, $index_name
    );
    if ($invalid) {
        my $rv = $dbh_db->do("DROP INDEX CONCURRENTLY IF EXISTS $index_name");
        if ( !defined $rv ) {
            warn "[ERROR] Database: $db | DROP invalid $index_name failed: $DBI::errstr\n";
            return;
        }
        print "[INFO] Database: $db | invalid index deleted $index_name\n";
    }

    my ($exists) = $dbh_db->selectrow_array( "SELECT to_regclass(?)", undef, $index_name );
    if ( defined $exists ) {
        print "[SKIP] Database: $db | index $index_name already exists\n";
        return;
    }

    my $rv = $dbh_db->do(
        "CREATE INDEX CONCURRENTLY IF NOT EXISTS $index_name ON $table_name (transdate, trans_id)"
    );
    if ( !defined $rv ) {
        warn "[ERROR] Database: $db | CREATE INDEX CONCURRENTLY failed: $DBI::errstr\n";
    }
    else {
        print "[OK] Database: $db | index $index_name created\n";
    }
}

my $dbs = $dbh->selectcol_arrayref(
    "SELECT datname FROM pg_database WHERE datistemplate = false AND datallowconn = true ORDER BY datname"
);

for my $db (@$dbs) {
    my $dbh_db = DBI->connect(
        "DBI:$driver:dbname=$db;host=$dbHost",
        $userid,
        $password,
        { RaiseError => 0, PrintError => 0, AutoCommit => 1 }
    );

    if ( !$dbh_db ) {
        warn "[ERROR] Failed to connect to database '$db'. Error: $DBI::errstr\n";
        next;
    }

    create_index_concurrently( $db, $dbh_db );
    $dbh_db->disconnect();
}

$dbh->disconnect();