#!/usr/bin/perl
use strict;
use warnings;
use File::Type;


my $input_fh;

if (@ARGV) {
    open($input_fh, "<", $ARGV[0]) || die $!;
}
else {
    $input_fh = *STDIN;
}

my $buf;
read $input_fh, $buf, 1024;

my $filetype = File::Type->new()->checktype_contents($buf);

my %cat_tools = (
    'application/x-gzip'       => 'gzip  -cd',
    'application/x-bzip2'      => 'bzip2 -cd',
);

unless (exists $cat_tools{$filetype}) {
    $cat_tools{$filetype} = 'cat';
    warn "$0: '$filetype' detected, piping through *cat*.\n";
}
    
open(my $cmd_handle, "|-", $cat_tools{$filetype}) || die $!;

print $cmd_handle $buf; # pipe what we already have

while (read $input_fh, $buf, 1024) { # pipe remaining data
    print $cmd_handle $buf;
}

close $cmd_handle;
close $input_fh if @ARGV;
