################ #########
package SL::Model::Config;
##########################
use strict;
use warnings;
use feature ':5.10';
use Carp;
use Cwd 'abs_path';
use File::Basename;
use File::Spec;
use Data::Dumper;

my $_self;



sub new {
    my $class = shift;
    my ($c) = @_; # Optional: Mojolicious Controller *OR* simple username

    $_self = {};

    bless $_self, $class;

    my $this_module_dir = dirname abs_path __FILE__;
    
    # -> e.g. /home/user1/projects/runmyaccounts/mojo/lib/SL/Model
    
    # Throw away last 4 components to get the project root:
    my @dirs = File::Spec->splitdir($this_module_dir);
    splice @dirs, -4;
    my $pr = File::Spec->catdir(@dirs);

    $_self->{globalconfig}{x_project_root} = $pr;

    my $global_configfile = "$pr/sql-ledger.conf";
    
    our ($spool, $language, $userspath);
    eval { require $global_configfile };

    unless ($@) {
        my %map = (
            language  => $language  // '',
            spool     => $spool     // 'spool',
            userspath => $userspath // 'users', 
        );

        foreach my $k (keys %map) {
            $_self->{globalconfig}{$k} = $map{$k};
        }
    }

    if ($c) {
        my $username = $c->isa('Mojolicious::Controller')?
            $c->session('login_name') : $c;
        
        our %myconfig;
        my $user_configfile = File::Spec->catfile(
            $_self->val('x_project_root'),
            $_self->val('userspath'),
            "$username.conf");

        eval { require $user_configfile };
        if ($@) { die "Cannot load user config for $username" }

        $_self->{userconfig} = \%myconfig;


        # Add some additional useful fields.
        # We name them "x_" for easy recognition:
        
        $_self->{userconfig}{x_login_name} = $username;

        
        # Build dateformats for strptime.
        # One to match a four-digit year, and one for two-digit years:
        my @dfs = (
            $_self->{userconfig}{dateformat},
            $_self->{userconfig}{dateformat},
        );
        
        map { s/dd/%d/ }   @dfs;
        map { s/mm/%m/ }   @dfs;
        map { s/yyyy/%Y/ } @dfs;
        
        if (grep { /yy/ } @dfs) {
            $dfs[0] =~ s/yy/%Y/;
            $dfs[1] =~ s/yy/%y/;
        }

        $_self->{userconfig}{x_dateformat_strptime} = \@dfs;


        # my spool directory:
        $_self->{userconfig}{x_myspool} = File::Spec->catfile(
            $_self->{globalconfig}{x_project_root},
            $_self->{globalconfig}{spool},
            $_self->{userconfig}{x_login_name},
        );

        # Language:
        my $lang = $_self->{userconfig}{countrycode} || 'en';
        $lang =~ s/^(..).*/$1/; # Only first two letters
        $_self->{userconfig}{x_language} = $lang;
    }

    return $_self;
}        


sub instance {
    my $class = shift;

    if (defined $_self && @_) {
        return $class->new(@_);
    }

    return $_self // $class->new(@_);
}


sub val {
    my $self = shift;
    my ($key) = @_;

    return $self->{userconfig}{$key} // $self->{globalconfig}{$key};
}



1;
