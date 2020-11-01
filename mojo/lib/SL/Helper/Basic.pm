package SL::Helper::Basic;
use base 'Mojolicious::Plugin';
use strict;
use warnings;
use v5.10;

use lib ("mojo/lib");
use SL::Model::Config;


sub register {

    my ($self, $app) = @_;

    $app->helper(
        userconfig => sub {
            my $self = shift;

            my $conf  = SL::Model::Config->instance($self);

            return $conf;
        }
    );

    $app->helper(
        # We have to implement our own cookie parser, because SL uses
        # cookie names like "SL-root login", which is not RFC 6265
        # compatible, and Mojolicious parses them wrong :-(
        
        # https://www.perlmonks.org/bare/?node_id=99379
        cookies => sub {
            my $self = shift;

            my $cookie_raw = $self->req->headers->cookie;

            my %decode = ('\+'=>' ','\%3A\%3A'=>'::','\%26'=>'&','\%3D'=>'=',
                          '\%2C'=>',','\%3B'=>';','\%2B'=>'+','\%25'=>'%');

            my %cookies = ();
            foreach (split(/; /, $cookie_raw)) {
                my ($cookie, $value) = split(/=/);
                foreach my $ch ('\+','\%3A\%3A','\%26','\%3D','\%2C','\%3B','\%2B','\%25') {
                    $cookie =~ s/$ch/$decode{$ch}/g;
                    $value =~ s/$ch/$decode{$ch}/g;
                }
                $cookies{$cookie} = $value;
            }
            return \%cookies;
        }
    );


    $app->helper( # The user pages dont need this, because it is in config.
        admin_pg_connstr => sub {
            my $self = shift;
            my %args = @_;

            $self->session(dbhost    => $args{dbhost})    if $args{dbhost};
            $self->session(dbdefault => $args{dbdefault}) if $args{dbdefault};
            $self->session(dbname    => $args{dbname})    if $args{dbname};
            $self->session(dbuser    => $args{dbuser})    if $args{dbuser};
            $self->session(dbpasswd  => $args{dbpasswd})  if $args{dbpasswd};
            $self->session(dbport    => $args{dbport})    if $args{dbport};
            
            my $connstr = "";
            $connstr .= "postgresql://";
            $connstr .= $self->session('dbuser');
            $connstr .= ':';
            $connstr .= $self->session('dbpasswd')
                if $self->session('dbpasswd');
            $connstr .= '@';
            $connstr .= $self->session('dbhost');
            $connstr .= (':' . $self->session('dbport'))
                if $self->session('dbport');
            $connstr .= '/';
            $connstr .= ($self->session('dbname') // $self->session('dbdefault'));

            return $connstr;
        }
    );


    $app->helper( # render an exception page
        exception => sub {
            my $self = shift;
            my ($short, $long) = @_;

            $self->render(template => "error",
                          short    => $short,
                          long     => $long);
            return 1;
        }
    );
    
    $app->helper( # render an exception page if an exception ($@) happened
        exception_happened => sub {
            my $self = shift;
            my ($short, $long) = @_;

            return 0 unless $@;

            $self->render(template => "error",
                          short    => $short // 'Error',
                          long     => ($long // $@ // undef));

            return 1;
        }
    );
    
}

1;
