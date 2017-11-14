#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/mojo/lib";

use Mojolicious::Commands;

Mojolicious::Commands->start_app('SL');
