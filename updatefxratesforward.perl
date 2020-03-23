#!/usr/bin/perl

use Data::Dumper;              # Perl core module
use strict;                    # Good practice
use warnings;                  # Good practice

use DBI;
use DBIx::Simple;

my $dbh = DBI->connect( "dbi:Pg:dbname=ledger28", "postgres", "" );
my $dbs = DBIx::Simple->connect($dbh);

my ($transdate) = $dbh->selectrow_array("SELECT current_date");
# my $transdate = '2019-06-16';

my @rates = $dbs->query("SELECT curr, transdate, buy, sell FROM exchangerate WHERE transdate = ?", $transdate)->hashes;

for my $i (1 .. 30){
   $transdate = $dbs->query("SELECT '$transdate'::date + 1")->list;
   for my $row (@rates){
       $dbs->query("INSERT INTO exchangerate VALUES (?,?,?,?)", $row->{curr}, $transdate, $row->{buy}, $row->{sell});
   }
   print "Rates added for $transdate\n";
}

$dbh->disconnect;

