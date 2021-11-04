package SL::Helper::DateIntervalPicker;
use base 'Mojolicious::Plugin';
use strict;
use warnings;
use v5.10;

use lib ("mojo/lib");
use SL::Model::Config;
use Time::Piece;
use Time::Seconds;


sub register {

    my ($self, $app) = @_;

    $app->helper(
        foo => sub {
            my $self = shift;

            my ($t1, $t2);

            my $fromdate = $self->param('fromdate');
            my $todate   = $self->param('todate');
            
            my $month    = $self->param('month');
            my $year     = $self->param('year');
            my $interval = $self->param('interval');


            # Either we have exact specification From date .. To date:
            if ($fromdate && $todate) {

                my $formats = $self->userconfig->val('x_dateformat_strptime');
     
                eval { # For most dateformats the 4-digit year version:
                    # Let strptime be more "strict":
                    local $SIG{__WARN__} = sub { die };
                    $t1 = Time::Piece->strptime($fromdate, $formats->[0]);
                    $t2 = Time::Piece->strptime($todate,   $formats->[0]);
                };

                if ($@) { # Otherwise with 2-digit year:
                    eval { # Otherwise with 2-digit year:
                        local $SIG{__WARN__} = sub { die };
                        $t1 = Time::Piece->strptime($fromdate, $formats->[1]);
                        $t2 = Time::Piece->strptime($todate,   $formats->[1]);
                    };
                }
            }
            
            else {  # the interval stuff:
                my $from;
                
                if (!$month && $year) {
                    $from = "$year-01-01"
                }
                elsif ($month && $year) {
                    $from = "$year-$month-01"
                }
                else { # month but no year or nothing at all
                    return;
                }
                
                eval {
                    local $SIG{__WARN__} = sub { die };
                    $t1 = Time::Piece->strptime($from, "%Y-%m-%d");
                };
                return if $@;
                
                return unless defined $interval;
                
                if ($interval eq '0') {
                    my $t = localtime;
                    $t2 = $t->ymd;
                }
                elsif ($interval eq '1' && $month) {
                    $t2 = $t1->add_months(1);
                    $t2 -= ONE_DAY;
                }
                elsif ($interval eq '3' && $month) {
                    $t2 = $t1->add_months(3);
                    $t2 -= ONE_DAY;
                }
                elsif ($interval eq '12' ) {
                    $t2 = $t1->add_years(1);
                    $t2 -= ONE_DAY;
                }
            }

            # Finally detect type of interval:
            my $delta = $t2 - $t1;
            my $days = $delta->days;

            my $interval_text;

            if ($days >=25 && $days <= 35) {
                $interval_text = 'month';
            }
            elsif ($days >=85 && $days <= 95) {
                $interval_text = 'quarter';
            }
            elsif ($days >= 360 && $days <= 370) {
                $interval_text = 'year';
            }
            
            return ($t1->ymd, $t2->ymd, $interval_text);
        }
    );

    
}

1;
