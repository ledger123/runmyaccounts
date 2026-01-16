#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use File::Spec;
use File::Basename;

# Integration
my $dbHost   = "192.168.8.17";
# Production
#my $dbHost   = "192.168.9.20";
my $driver   = "Pg";
my $userid   = "sql-ledger";
my $password = "";

my $backup_dir = '/home/change_me';

sub restore_customer_vendor {
    my ($db, $dbh) = @_;
    my $backup_file = File::Spec->catfile($backup_dir, "${db}_customer_vendor_backup");
    unless (-e $backup_file) {
        warn "[ERROR] Backup file $backup_file does not exist. Skipping $db\n";
        return;
    }
    open my $fh, '<', $backup_file or do {
        warn "[ERROR] Cannot open $backup_file for reading: $!\n";
        return;
    };
    my $count = 0;
    while (my $line = <$fh>) {
        chomp $line;
        next if $line =~ /^#/ || $line =~ /^\s*$/;
        my ($table, $id, $payment_accno_id) = split /,/, $line;
        next unless $table && $id && defined $payment_accno_id;
        my $sth = $dbh->prepare("UPDATE $table SET payment_accno_id = ? WHERE id = ?");
        my $rv = $sth->execute($payment_accno_id, $id);
        if (!defined $rv) {
            warn "[ERROR] Database: $db | Table: $table | id: $id | Failed: $DBI::errstr\n";
        } else {
            $count++;
        }
        $sth->finish();
    }
    close $fh;
    print "[OK] Restored $count records for $db from $backup_file\n";
}

sub revert_db {
    my $dsn = "DBI:$driver:dbname=template1;host=$dbHost";
    my $dbh = DBI->connect($dsn, $userid, $password, { RaiseError => 1 });
    my $dbs = $dbh->selectcol_arrayref(
        "SELECT datname FROM pg_database WHERE datistemplate = false;"
    );
    $dbh->disconnect();

    for my $db (@$dbs) {
        my $database_dsn = "DBI:$driver:dbname=$db;host=$dbHost";
        my $dbh = DBI->connect(
            $database_dsn,
            $userid,
            $password,
            { RaiseError => 0, PrintError => 0 }
        );
        if (!$dbh) {
            warn "[ERROR] Failed to connect to database '$db'. Error: $DBI::errstr\n";
            next;
        }
        restore_customer_vendor($db, $dbh);
        $dbh->disconnect();
    }
}

revert_db();


