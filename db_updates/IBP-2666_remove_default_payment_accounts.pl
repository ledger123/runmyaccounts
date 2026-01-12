#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use File::Path qw(make_path);
use POSIX qw(strftime);

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

my $backup_dir = '/home/change_me';

sub backup_customer_vendor {
    my ($db, $dbh) = @_;
    make_path($backup_dir) unless -d $backup_dir;
    my $backup_file = "$backup_dir/${db}_customer_vendor_backup";
    open my $fh, '>', $backup_file or do {
        warn "[ERROR] Cannot open $backup_file for writing: $!\n";
        return;
    };
    print $fh "# id,payment_accno_id\n";
    for my $table (qw(customer vendor)) {
        my $sth = $dbh->prepare("SELECT id, payment_accno_id FROM $table WHERE payment_accno_id IS NOT NULL AND payment_accno_id <> ''");
        $sth->execute();
        while (my $row = $sth->fetchrow_hashref) {
            print $fh "$table,$row->{id},$row->{payment_accno_id}\n";
        }
        $sth->finish();
    }
    close $fh;
    print "[OK] Backup for $db written to $backup_file\n";
}

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

        backup_customer_vendor($db, $dbh);

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
UPDATE customer SET payment_accno_id = NULL
},
    q{
UPDATE vendor SET payment_accno_id = NULL
},
);

$dbh->disconnect();

