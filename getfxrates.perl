#!/usr/bin/perl

use LWP::Simple;               # From CPAN
use JSON qw( decode_json );    # From CPAN
use Data::Dumper;              # Perl core module
use strict;                    # Good practice
use warnings;                  # Good practice

my $trendsurl = "http://free.currencyconverterapi.com/api/v5/convert?q=CHF_EUR&compact=y&apiKey=5dx23c40c9d4df160617";
my $json      = get($trendsurl);
die "Could not get $trendsurl!" unless defined $json;
my $decoded_json = decode_json($json);
my $chf          = $decoded_json->{'CHF_EUR'}->{'val'};

$trendsurl = "http://free.currencyconverterapi.com/api/v5/convert?q=USD_EUR&compact=y&apiKey=5dc4062ec9du234d0617";
$json      = get($trendsurl);
die "Could not get $trendsurl!" unless defined $json;
$decoded_json = decode_json($json);
my $usd = $decoded_json->{'USD_EUR'}->{'val'};

use DBI;

my $dbh = DBI->connect( "dbi:Pg:dbname=ledger28", "postgres", "" );
my ($transdate) = $dbh->selectrow_array("SELECT current_date");

my ($found) = $dbh->selectrow_array("SELECT 1 FROM exchangerate WHERE curr='EUR' AND transdate='$transdate'");

if ( !$found ) {
    $dbh->do("INSERT INTO exchangerate (curr, transdate, buy, sell) VALUES ('EUR', '$transdate', 1, 1)");
}

($found) = $dbh->selectrow_array("SELECT 1 FROM exchangerate WHERE curr='CHF' AND transdate='$transdate'");

if ( !$found ) {
    $dbh->do("INSERT INTO exchangerate (curr, transdate, buy, sell) VALUES ('CHF', '$transdate', $chf, $chf)");
}

($found) = $dbh->selectrow_array("SELECT 1 FROM exchangerate WHERE curr='USD' AND transdate='$transdate'");

if ( !$found ) {
    $dbh->do("INSERT INTO exchangerate (curr, transdate, buy, sell) VALUES ('USD', '$transdate', $usd, $usd)");
}

$dbh->disconnect;

