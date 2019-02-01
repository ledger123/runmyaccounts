package SL::Helpers;
use base 'Mojolicious::Plugin';
use strict;
use warnings;
use Cwd;
use Storable;
use v5.10;
use File::Path qw(make_path remove_tree);

use lib ("mojo/lib");
use SL::Model::Config;
use Time::Piece;
use Mojo::Pg;
use File::pushd;


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
    
    $app->validator->add_check(
        valid_date => sub {
            my ($validation, $name, $value, ($conf, $ref)) = @_;

            my $formats = $conf->val('x_dateformat_strptime');

            # Let strptime be more "strict":
            local $SIG{__WARN__} = sub { die };
            
            my $t;
            eval { # For most dateformats the 4-digit year version:
                $t = Time::Piece->strptime($value, $formats->[0]);
            };
            if (!$@) {
                $$ref = $t->ymd;
                return undef;
            }

            eval { # Otherwise with 2-digit year:
                $t = Time::Piece->strptime($value, $formats->[1]);
            };
            if (!$@) {
                $$ref = $t->ymd;
                return undef;
            }

            return 1; # Not ok
        }
    );


    $app->helper(
        private_spool_realm => sub {
            my $c = shift;
            my ($realm, %args) = @_;
            $args{empty} //= 0; 

            my $myspool = $c->userconfig->val('x_myspool');
            -d $myspool || make_path($myspool, {mode => 0700});
            -w $myspool || die "Private spool is not writeable.";

            my $spooldir = pushd($myspool);
            my $realmdir;
            
            remove_tree($realm) if $args{empty};
            make_path($realm, {mode => 0700});

            {
                $realmdir = pushd($realm);
            }

            return $realmdir;
        }
    );

    $app->helper(
        mojo_pg => sub {
            my $c = shift;

            my $myspool = $c->userconfig->val('x_myspool');
            -d $myspool || make_path($myspool) || die $!;
            
            my $access_data;
            my $access_data_file
                = File::Spec->catfile($myspool, "access_data");;
            
            if ($c->param('dbuser')) {
                # We are most likely in "Accounting / Database Administration"
                # Let's pick up all these values and store them in a
                # personal spool file for future use: 
            
                $access_data = {
                    dbuser    => $c->param('dbuser'),
                    dbpasswd  => $c->param('dbpasswd'),
                    dbhost    => $c->param('dbhost'),
                    dbport    => $c->param('dbport'),
                    dbname    => $c->param('dbname'),
                    dbdefault => $c->param('dbdefault'),
                };
            }
            else { # no dbuser given
                $access_data = retrieve($access_data_file);

                # merge current params
                foreach (qw(dbuser dbpasswd dbhost dbport dbname dbdefault)) {
                    $access_data->{$_} = $c->param($_)
                        if defined $c->param($_);
                }
            }

            store $access_data, $access_data_file;
            my $connstr = _build_connstr($access_data);

            state $pg = Mojo::Pg->new($connstr);

            return {
                object => $pg,
                connstr => $connstr,
                access_data => $access_data,
            };
        }
    );

    
    $app->helper(
        exception => sub {
            # For use in a Mojolicious controller.
            
            # Use case 1: 
            # $c->exception("Bad things") && return;
            # ==> Render error page without detail; return 1

            # Use case 2: 
            # $c->exception("Bad things", "Detailed message") && return;
            # ==> Render error page with detail button; return 1

            # Use case 3: 
            # $c->exception("Bad things", qr/RegExp/) && return;
            # ==> Render error page only if $@ matches RegExp.
            #     The Detail will be $@. Return 0|1

            my $c = shift;
            
            my ($short, $param2, $additional) = @_;

            
            if (defined $param2 && ref $param2) { # RegExp
                if ($@ =~ $param2) {
                    $c->render('error',
                               short => $short,
                               long => $@,
                               additional => $additional);
                    return 1;
                }
                else {
                    return 0;
                }
            }
            else {
                $c->render('error',
                           short => $short,
                           long => $param2,
                           additional => $additional);
                return 1;
            }

        }
    );

    
}


sub _build_connstr {
    my ($access_data) = @_;

    my $connstr = "";
    $connstr .= "postgresql://";
    $connstr .= "$access_data->{dbuser}";
    $connstr .= ':';
    $connstr .= "$access_data->{dbpasswd}";
    $connstr .= '@';
    $connstr .= "$access_data->{dbhost}";
    $connstr .= ":$access_data->{dbport}" if $access_data->{dbport};
    $connstr .= '/';
    if ($access_data->{dbname}) {
        $connstr .= $access_data->{dbname};
    }
    else {
        $connstr .= $access_data->{dbdefault};
    }
 
    return $connstr;
}

1;
