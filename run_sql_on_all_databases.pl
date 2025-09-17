#!/usr/bin/perl

use strict;
use warnings;
use DBI;

# Integration
my $dbHost   = "192.168.8.17";
# Production
# my $dbHost   = "192.168.9.20";
my $driver   = "Pg";
my $database = "harvesttest";
my $dsn      = "DBI:$driver:dbname=$database;host=$dbHost";
my $userid   = "sql-ledger";
my $password = "";

my $dbh = DBI->connect( $dsn, $userid, $password, { RaiseError => 1 } )
  or die $DBI::errstr;

sub run_queries_on_all_dbs {
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

run_queries_on_all_dbs(
    # Add last_modified column to customer table if it doesn't exist
    q{
ALTER TABLE public.customer
    ADD COLUMN IF NOT EXISTS last_modified TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
},

    # Add last_modified column to vendor table if it doesn't exist
    q{
ALTER TABLE public.vendor
    ADD COLUMN IF NOT EXISTS last_modified TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
},

    # Create or replace function to automatically update last_modified column on row update
    q{
CREATE OR REPLACE FUNCTION public.update_last_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_modified := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql
},

    # Drop old trigger for customer table if it exists
    q{DROP TRIGGER IF EXISTS trg_set_last_modified_customer ON public.customer},

    # Create trigger for customer table to update last_modified before each update
    q{
CREATE TRIGGER trg_set_last_modified_customer
    BEFORE UPDATE ON public.customer
    FOR EACH ROW
    EXECUTE FUNCTION public.update_last_modified_column()
},

    # Drop old trigger for vendor table if it exists
    q{DROP TRIGGER IF EXISTS trg_set_last_modified_vendor ON public.vendor},

    # Create trigger for vendor table to update last_modified before each update
    q{
CREATE TRIGGER trg_set_last_modified_vendor
    BEFORE UPDATE ON public.vendor
    FOR EACH ROW
    EXECUTE FUNCTION public.update_last_modified_column()
},

    # Update version in defaults table
    q{
UPDATE public.defaults 
SET fldvalue = '2.8.46' 
WHERE fldname LIKE 'version'
},
);

$dbh->disconnect();