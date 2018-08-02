package SL::Helpers;
use base 'Mojolicious::Plugin';
use Cwd;

use lib ("mojo/lib");
use SL::Model::Config;
use Time::Piece;


sub register {

    my ($self, $app) = @_;

    $app->helper(
        userconfig => sub {
            my $self = shift;

            my $conf  = SL::Model::Config->instance($self);

            return $conf;
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

    
}

1;
