#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use FindBin;

# Integration
my $dbHost = "192.168.8.17";
# Production
#my $dbHost = "192.168.9.20";
my $userid = "sql-ledger";
my $password = "";

my $migration = "$FindBin::Bin/../sql/Pg-upgrade-2.8.52-2.8.53.sql";
open my $sql_file, '<', $migration or die "Cannot open $migration: $!\n";
my $sql = do { local $/; <$sql_file> };
close $sql_file or die "Cannot close $migration: $!\n";

my $dbh = DBI->connect(
    "DBI:Pg:dbname=einzelfirma;host=$dbHost", $userid, $password,
    { RaiseError => 1, PrintError => 0 }
);
my $dbs = $dbh->selectcol_arrayref(
    "SELECT datname FROM pg_database WHERE datistemplate = false"
);
$dbh->disconnect;

for my $db (@$dbs) {
    my $dataset = DBI->connect(
        "DBI:Pg:dbname=$db;host=$dbHost", $userid, $password,
        { RaiseError => 1, PrintError => 0 }
    ) or die "Cannot connect to database '$db': $DBI::errstr\n";

    my ($defaults) = $dataset->selectrow_array("SELECT to_regclass('defaults')");
    if (!$defaults) {
        print "[SKIP] Database '$db' has no ledger defaults table\n";
        $dataset->disconnect;
        next;
    }

    my ($version) = $dataset->selectrow_array(
        "SELECT fldvalue FROM defaults WHERE fldname = 'version'"
    );
    die "Database '$db' must be at version 2.8.52 or 2.8.53\n"
        unless defined $version && ($version eq '2.8.52' || $version eq '2.8.53');

    # Use the same atomic migration as the application upgrade loader.
    $dataset->do($sql) or die "Migration failed for database '$db': $DBI::errstr\n";
    $dataset->disconnect;
    print "[OK] Database '$db' updated to 2.8.53\n";
}
