#!/bin/perl

use strict;
use warnings;

use URI qw( );
my $uri = "http://www.MyDomain.com/SomefolderPath/ImageName256.jpg";

$uri =~ s!\.\w+/(.+?)/[^/]+\?*?!$1!;
my $path= $1;

print $path;
