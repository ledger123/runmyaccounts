#!/usr/bin/env perl

use strict;
use warnings;
use DBIx::Simple;
use Data::Dumper;
use Text::CSV;

my $importfile = 'sample.se';
my $dbname     = 'test';
my $curr       = 'SEK';

#
# STEP 1: Import Chart
#
my %categories = (
    '1' => 'Assets',
    '2' => 'Liabilities',
    '3' => 'Equity',
    '4' => 'Revenues',
    '5' => 'Expenses'
);

my %category_codes = (
    'Assets'      => 'A',
    'Liabilities' => 'L',
    'Equity'      => 'Q',
    'Revenues'    => 'I',
    'Expenses'    => 'E',
);

open my $fh,  '<', $importfile or die "Cannot open $importfile: $!";
open my $csv, '>', 'chart.csv' or die "Cannot open chart.csv: $!";

print $csv "accno,description,gifi_accno,charttype,category\n";

my %accounts;
my %sru;
my $last_category;

while ( my $line = <$fh> ) {
    chomp $line;
    if ( $line =~ /^#KONTO\s+(\d+)\s+"([^"]+)"/ ) {
        $accounts{$1} = $2;
    } elsif ( $line =~ /^#SRU\s+(\d+)\s+(\d+)/ ) {
        $sru{$1} = $2;
    }
}

foreach my $acc_num ( sort keys %accounts ) {
    my $category_char = substr( $acc_num, 0, 1 );
    my $category_desc = $categories{$category_char}     // "Other";
    my $category_code = $category_codes{$category_desc} // '';

    if ( !defined($last_category) || $last_category ne $category_char ) {
        print $csv "$category_char,\"$category_desc\",,H,$category_code\n";
        $last_category = $category_char;
    }
    my $description = $accounts{$acc_num};
    my $sru_code    = $sru{$acc_num} // '';
    print $csv "$acc_num,\"$description\",$sru_code,A,$category_code\n";
}

close $fh;
close $csv;

my $db = DBIx::Simple->connect( "dbi:Pg:dbname=$dbname", 'postgres', '', { RaiseError => 1, AutoCommit => 1 } ) or die DBIx::Simple->error;

open my $csv_read, '<', 'chart.csv' or die "Cannot open chart.csv: $!";

my $csv_parser = Text::CSV->new( { binary => 1, auto_diag => 1, allow_whitespace => 1 } );

# Skip header line
$csv_parser->getline($csv_read);

while ( my $row = $csv_parser->getline($csv_read) ) {
    my ( $accno, $description, $gifi_accno, $charttype, $category ) = @$row;

    my $exists = $db->query( "SELECT 1 FROM chart WHERE accno = ?", $accno )->list;

    if ($exists) {
        print "Skipped accno $accno (already exists)\n";
    } else {
        my $data = {
            accno       => $accno,
            description => $description,
            gifi_accno  => $gifi_accno,
            charttype   => $charttype,
            category    => $category
        };

        print Dumper($data);
        $db->insert( 'chart', $data ) or die $db->error;
        print "Inserted accno $accno\n";
    }
}

close $csv_read;
$db->disconnect;

#
# STEP 2: Import transactions
#

open my $fh,  '<', $importfile or die "Cannot open transactions.sie: $!";
open my $csv, '>', 'trans.csv' or die "Cannot open transactions.csv: $!";

print $csv "reference,accno,amount,description,transdate\n";

my $current_ver;
my $text;
my $date;

while ( my $line = <$fh> ) {
    chomp $line;
    if ( $line =~ /^#VER\s+\w+\s+(\d+)\s+(\d+)\s+"([^"]+)"\s+(\d+)/ ) {
        $current_ver = sprintf( "%06d", $1 );              # Pad with leading zeros to length of 6
        $text        = $3;
        my $raw_date = $4;
        $raw_date =~ s/(\d{4})(\d{2})(\d{2})/$1-$2-$3/;    # Format the date as 'YYYY-MM-DD'
        $date = $raw_date;

    } elsif ( $line =~ /^#TRANS\s+(\d+)\s+\{\}\s+(-?\d+\.?\d*)\s+""\s+""\s+0/ ) {
        my $account = $1;
        my $amount  = $2;
        print $csv "$current_ver,$account,$amount,\"$text\",$date\n";
    }
}

close $fh;
close $csv;

my $csv = Text::CSV->new( { binary => 1, auto_diag => 1 } );
open my $fh, '<', 'trans.csv' or die "Cannot open transactions.csv: $!";

$csv->getline($fh);

my $db = DBIx::Simple->connect( "dbi:Pg:dbname=$dbname", 'postgres', '', { RaiseError => 1, AutoCommit => 1 } ) or die DBIx::Simple->error;

my $last_reference = '';
my $trans_id;

while ( my $row = $csv->getline($fh) ) {
    my ( $reference, $accno, $amount, $description, $transdate ) = @$row;

    if ( $reference ne $last_reference ) {

        my ($existing_trans_id) = $db->query( "SELECT id FROM gl WHERE reference = ?", $reference )->list;
        if ( defined $existing_trans_id ) {
            print "Reference $reference already exists in 'gl'.\n";
            $trans_id = $existing_trans_id;
            next;
        } else {
            $db->query( "INSERT INTO gl (reference, transdate, description, curr) VALUES (?, ?, ?, ?)", $reference, $transdate, $description, $curr );
            print "Inserted into 'gl': $reference\n";
            ($trans_id) = $db->query( "SELECT max(id) FROM gl WHERE reference = ?", $reference )->list;
        }
        $last_reference = $reference;
    }

    my ($chart_id) = $db->query( "SELECT id FROM chart WHERE accno = ?", $accno )->list;

    $db->query( "INSERT INTO acc_trans (trans_id, chart_id, amount) VALUES (?, ?, ?)", $trans_id, $chart_id, $amount );
    print "Inserted into 'acc_trans': trans_id = $trans_id, chart_id = $chart_id, amount = $amount\n";
}

close $fh;

$db->disconnect;

