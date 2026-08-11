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
use Mojo::Home;

my $_self;



sub new {
    my $class = shift;
    my ($c) = @_; # Optional: Mojolicious Controller *OR* simple username

    $_self = {};

    bless $_self, $class;

    # Detect application home:
    my $pr = Mojo::Home->new->detect->to_string;

    # Do we really have the project root? If not, try another method:
    if (! -e "$pr/mojo.pl") {
        my @path = File::Spec->splitdir( __FILE__ );
        splice @path, -5;

        $pr = File::Spec->catfile(@path);

        if (! -e "$pr/mojo.pl") {
            die "Cannot detect project root\n";
        }
    }


    
    
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
        
        # User config lives in the SQLite members database
        # (users/members.db) rather than in users/*.conf files:
        unshift @INC, $_self->val('x_project_root')
            unless grep { $_ eq $_self->val('x_project_root') } @INC;
        require SL::User;

        my $memfile = File::Spec->catfile(
            $_self->val('x_project_root'),
            $_self->val('userspath'),
            "members");

        my %userconfig = User::load_myconfig($memfile, $username);
        if (!%userconfig) { die "Cannot load user config for $username" }

        my $is_root = $username eq 'root login';

        $_self->{userconfig} = \%userconfig;


        # Add some additional useful fields.
        # We name them "x_" for easy recognition:
        
        $_self->{userconfig}{x_login_name} = $username;


        if (!$is_root) {
            # Build dateformats for strptime.
            # One to match a four-digit year, and one for two-digit years:
            my @dfs = (
                $_self->{userconfig}{dateformat} // "",
                $_self->{userconfig}{dateformat} // "",
            );
            
            map { s/dd/%d/ }   @dfs;
            map { s/mm/%m/ }   @dfs;
            map { s/yyyy/%Y/ } @dfs;
            
            if (grep { /yy/ } @dfs) {
                $dfs[0] =~ s/yy/%Y/;
                $dfs[1] =~ s/yy/%y/;
            }
            
            $_self->{userconfig}{x_dateformat_strptime} = \@dfs;

            
            # Connection string for Mojo::Pg
            my $connstr = "";
            $connstr .= "postgresql://";
            $connstr .= $_self->val('dbuser');
            $connstr .= ':';
            $connstr .= unpack 'u', $_self->val('dbpasswd');
            $connstr .= '@';
            $connstr .= $_self->val('dbhost');
            $connstr .= (':' . $_self->val('dbport')) if $_self->val('dbport');
            $connstr .= '/';
            $connstr .= $_self->val('dbname');
            
            $_self->{userconfig}{x_pg_connstr} = $connstr;
        }

        
        # my spool directory:
        $_self->{userconfig}{x_myspool} = File::Spec->catfile(
            $_self->{globalconfig}{x_project_root},
            $_self->{globalconfig}{spool},
            $_self->{userconfig}{x_login_name},
        );

        # Language:
        my $lang;

        if (exists $_self->{userconfig}{countrycode} &&
                $_self->{userconfig}{countrycode} eq '') {
            $_self->{userconfig}{x_language} = 'en';
        }
        
        $lang = $_self->{userconfig}{x_language} ||
            $_self->{userconfig}{countrycode} ||
            $_self->{globalconfig}{language} ||
            'en';
        $lang =~ s/^(..).*/$1/; # Only first two letters

        # For Mojo purposes we don't want to differentiate between
        # Swiss and German language. Maybe that changes in the future...
        $lang = 'de' if $lang eq 'ch';
        $_self->{userconfig}{x_language} = $lang;



        
        # Some root specials:
        if ($is_root) {
            # root needs no stylesheet, but this avoids warnings in the log:
            $_self->{userconfig}{stylesheet} = "root";
        }

        
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
