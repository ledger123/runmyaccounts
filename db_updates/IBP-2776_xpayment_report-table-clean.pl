#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use POSIX qw(strftime);

# Integration
my $dbHost   = "192.168.8.17";
# Production
#my $dbHost   = "192.168.9.20";
my $dbHost   = 5432;
my $driver   = "Pg";
my $database = "einzelfirma";
my $dsn      = "DBI:$driver:dbname=$database;host=$dbHost";
my $userid   = "sql-ledger";
my $password = "";

my $log_file = '/home/change_me/xpayment_report_removal.log';


my %skip_db = map { $_ => 1 } qw(
  template0
  template1
  postgres
);


sub log_line {
  my ($fh, $msg) = @_;
  my $ts = strftime('%Y-%m-%d %H:%M:%S', localtime);
  print $fh "[$ts] $msg\n";
}

open(my $LOG, '>>', $log_file) or die "Cannot open log file '$log_file': $!";

my $dsn_maint = "dbi:Pg:dbname=$database;host=$dbHost;port=$dbPort";
my $dbh_maint = DBI->connect(
  $dsn_maint,
  $userid,
  $password,
  {
    RaiseError => 1,
    PrintError => 0,
    AutoCommit => 1,
    pg_enable_utf8 => 1,
  }
);

my $db_list_sth = $dbh_maint->prepare(q{
  SELECT datname
  FROM pg_database
  WHERE datistemplate = false
  ORDER BY datname
});
$db_list_sth->execute();

my @dbs;
while (my ($dbname) = $db_list_sth->fetchrow_array) {
  next if $skip_db{$dbname};
  push @dbs, $dbname;
}

log_line($LOG, "Starting xpayment_report cleanup");
log_line($LOG, "Databases: " . join(', ', @dbs));


for my $dbname (@dbs) {

  my $dsn = "dbi:Pg:dbname=$dbname;host=$dbHost;port=$dbPort";
  my $dbh;

  eval {
    $dbh = DBI->connect(
      $dsn,
      $userid,
      $password,
      {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 0,
        pg_enable_utf8 => 1,
      }
    );

    my ($regclass) = $dbh->selectrow_array(q{
      SELECT to_regclass('public.xpayment_report')
    });

    if (!$regclass) {
      log_line($LOG, "$dbname: table xpayment_report does not exist – skipped");
      $dbh->commit();
      print "$dbname done.\n";
      goto NEXT_DB;
    }

    my ($table_size_before) = $dbh->selectrow_array(q{
      SELECT pg_size_pretty(pg_total_relation_size('public.xpayment_report'))
    });

    my ($db_size_before) = $dbh->selectrow_array(q{
      SELECT pg_size_pretty(pg_database_size(current_database()))
    });

    log_line($LOG, "$dbname: BEFORE delete | table_size=$table_size_before | db_size=$db_size_before");

    my $deleted = $dbh->do(q{
      DELETE FROM public.xpayment_report
      WHERE api_key IS NULL OR btrim(api_key) = ''
    });

    $deleted = 0 if (!defined $deleted || $deleted eq '0E0');

    my ($table_size_after) = $dbh->selectrow_array(q{
      SELECT pg_size_pretty(pg_total_relation_size('public.xpayment_report'))
    });

    my ($db_size_after) = $dbh->selectrow_array(q{
      SELECT pg_size_pretty(pg_database_size(current_database()))
    });

    $dbh->commit();

    log_line($LOG, "$dbname: AFTER delete  | table_size=$table_size_after | db_size=$db_size_after");
    log_line($LOG, "$dbname: xpayment_report records deleted: $deleted");

    print "$dbname done.\n";
  }
  or do {
    my $err = $@ || 'Unknown error';
    eval { $dbh->rollback() if $dbh };
    log_line($LOG, "$dbname: ERROR: $err");
    print "$dbname done.\n";
  };

NEXT_DB:
  eval { $dbh->disconnect() if $dbh };
}

log_line($LOG, "Finished xpayment_report cleanup");

eval { $dbh_maint->disconnect() };
close($LOG);

exit 0;