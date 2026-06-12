#!/usr/bin/perl
#
# sl-zugferd.pl -- thin Perl wrapper around zugferd/sl_zugferd.py.
#
# Usage:
#   bin/sl-zugferd.pl <invoice_id> <pdf_in> <pdf_out>
#
# Intended to be called from SL/Form.pm right after pdflatex has
# produced an invoice PDF, or manually from the command line:
#
#   perl zugferd/sl-zugferd.pl 1234 /tmp/inv.pdf /tmp/inv-zf.pdf
#
# The Python script reads its DB credentials from the config file
# pointed to by $ZUGFERD_CONFIG (default: zugferd/zugferd.conf).

use strict;
use warnings;
use File::Basename;
use File::Spec;

my ($invoice_id, $pdf_in, $pdf_out) = @ARGV;

unless ( defined $invoice_id && defined $pdf_in && defined $pdf_out ) {
    die "usage: $0 <invoice_id> <pdf_in> <pdf_out>\n";
}

my $here   = dirname( File::Spec->rel2abs($0) );
my $script = "$here/sl_zugferd.py";
my $config = $ENV{ZUGFERD_CONFIG} || "$here/zugferd.conf";

my @cmd = ( $ENV{PYTHON} || "$here/venv/bin/python3",
            $script,
            '--invoice-id', $invoice_id,
            '--pdf-in',     $pdf_in,
            '--pdf-out',    $pdf_out );

push @cmd, '--config', $config if -f $config;

my $rc = system(@cmd);
exit( $rc == 0 ? 0 : ( $rc >> 8 || 1 ) );