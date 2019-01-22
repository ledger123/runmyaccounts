#!/usr/bin/perl
use FindBin;
use lib "$FindBin::Bin/mojo/lib";

BEGIN {
    $ENV{MOJO_MAX_MESSAGE_SIZE} = 1024**3;

    # In current versions of Mojolicious this can be done in startup:
    # $self->max_request_size(1024**3);
}


use Mojolicious::Commands;

Mojolicious::Commands->start_app('SL');
