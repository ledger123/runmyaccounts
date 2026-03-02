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

sub customer_vendor_notes_converter {
    my @queries = @_;

    my $max_query_length = 0;
    for my $query (@queries) {
        $max_query_length = length($query) if length($query) > $max_query_length;
    }

    printf "+-%-30s-+-%-10s-+-%-${max_query_length}s-+\n", "-" x 30,        "-" x 10, "-" x $max_query_length;
    printf "| %-30s | %-10s | %-${max_query_length}s |\n", "Database Name", "Rows",   "Query";
    printf "+-%-30s-+-%-10s-+-%-${max_query_length}s-+\n", "-" x 30,        "-" x 10, "-" x $max_query_length;

    my $dbs = $dbh->selectcol_arrayref("SELECT datname FROM pg_database WHERE datistemplate = false;");

    for my $db (@$dbs) {
        my $database_dsn = "DBI:$driver:dbname=$db;host=$dbHost";
        my $dbh          = DBI->connect( $database_dsn, $userid, $password, { RaiseError => 0, PrintError => 0 } );

        if ( !$dbh ) {
            warn "Failed to connect to database '$db'. Error: $DBI::errstr\n";
            next;
        }

        for my $query (@queries) {
            my $rv = $dbh->do($query);
            if ( !defined $rv ) {
                warn "Failed to run query on database '$db'. Error: $DBI::errstr\n";
            } else {
                printf "| %-30s | %-10d | %-${max_query_length}s |\n", substr( $db, 0, 30 ), $rv, substr($query,0,50);
            }
        }

        $dbh->disconnect();
    }

    # Print table footer
    printf "+-%-30s-+-%-10s-+-%-${max_query_length}s-+\n", "-" x 30, "-" x 10, "-" x $max_query_length;
}

customer_vendor_notes_converter(
    # Update notes in customer table: replace newlines with <br>
    q{
UPDATE public.customer
SET notes = replace(notes, E'\n', '<br>')
WHERE notes LIKE E'%\n%'
},

    # Update notes in vendor table: replace newlines with <br>
    q{
UPDATE public.vendor
SET notes = replace(notes, E'\n', '<br>')
WHERE notes LIKE E'%\n%'
},
);

$dbh->disconnect();