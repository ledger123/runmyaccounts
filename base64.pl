#!/usr/bin/perl -X

use MIME::Base64 ('encode_base64');
use File::Slurper 'read_binary';

$infile = 'users/1584512788_invoice_D190344.pdf';

$raw_string = read_binary($infile);

$encoded = encode_base64( $raw_string );

#print $raw_string;

print $encoded;

