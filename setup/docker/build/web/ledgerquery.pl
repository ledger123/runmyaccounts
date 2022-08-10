#!/usr/bin/perl
use strict;
use warnings;
use feature ':5.10';
use Data::Dumper;

use lib qw(/srv/www/sql-ledger/mojo/lib);

use SL::Model::Config;
use SL::Model::SQL::Statement;

if (@ARGV < 2) {
    say "Usage: $0 USERNAME  YAML/KEY  [BIND_PARAMS...]";
    
    exit 1;
}

my ($username, $yaml_slash_key, @bind_values) = @ARGV;

my $conf = SL::Model::Config->instance($username);

my $sth = SL::Model::SQL::Statement->new(
    config => $conf,
    query  => $yaml_slash_key
);

$sth->execute(@bind_values);
my $result = $sth->fetch;

#say Dumper $result;


# Determine column widths:
my @col_widths = map { 0 } @{$result->[0]};

foreach my $row (@$result) {
    map { $_ //= 'NULL'; s/^\s+//; s/\s+$// } @$row;
    while (my ($index, $col) = each @$row) {
        if (length($col) > $col_widths[$index]) {
            $col_widths[$index] = length($col);
        }
    }
}


foreach my $row (@$result) {
    my $format = join(" | ", map { "%" . $_ . "s" } @col_widths);
    printf("$format\n", @$row);
}
