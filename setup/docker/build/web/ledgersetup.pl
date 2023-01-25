#!/usr/bin/perl
use strict;
use warnings;
use feature qw(say);
use File::Path qw(make_path remove_tree);
use YAML qw(LoadFile);
use Data::Dumper;
use File::Basename;
use Time::Piece;
use Getopt::Long;


BEGIN { # give up root identity and run as an unprivileged user ASAP

   use POSIX;
  
   my $run_as = $ENV{LEDGER_APACHE_RUN_USER};

   my ($uid, $gid) = ( getpwnam $run_as )[ 2, 3 ];

   die $! unless $uid && $gid;

   if ( $> == 0 ) {
      POSIX::setgid( $gid ); # GID must be set before UID!
      POSIX::setuid( $uid );
   }
   elsif ( $> != $uid )
   {
      warn <<__ABORT__ and exit 1;
** ABORT! **
   This application only runs as the "$run_as" user,
   not as your user account with ID: $>
__ABORT__
   }
}

say STDERR "Running as user: ", scalar(getpwuid( $< ));

#######################################################################


my $setup_info = {};

my %opts;

eval {
    GetOptions(
        \%opts,
        "initweb",
        "rootpw=s",
        "setup=s",
        "param=s@",
    ) || die;

    initweb() if exists $opts{initweb};
    
    setup() if exists $opts{setup};
};

if ($@) {
    warn $@;
    write_runinfo(error => $@);
    exit 1;
}

write_runinfo();



#############
sub initweb {
#############
    say STDERR "(Re)creating users/ and spool/ folder...";
    chdir($ENV{LEDGER_DOCUMENT_ROOT}) || die $!;

    remove_tree("users", "spool");
    make_path("users", "spool");

    say STDERR "(Re)creating users/members with single root entry...";

    my $rootpw = $opts{rootpw} // "secret";
    
    my $rootpw_hash = crypt($rootpw, "root");

    open(my $members, ">", 'users/members') || die $!;
    print $members <<EOF;
# Run my Accounts Accounting members

[root login]
password=$rootpw_hash
EOF
    close $members;
}



#################
sub wait_for_db {
#################
    # Eventually wait for db to come up:
    my $tries = 0;
    my $db_ready = 0;
    while ($tries <= 10) {
        
        if (system("pg_isready -h db") == 0) {
            $db_ready = 1;
            last;
        }

        say STDERR "Database cluster on host db is not yet ready. Waiting...";
        sleep 5;
        $tries++;
    }
    
    die "Database cluster on host db not reachable\n" unless $db_ready;
}


###########
sub setup {
###########

    say STDERR "Setup: $opts{setup}";

    wait_for_db();

    # Load YAML config:
    $setup_info = LoadFile("/ledgersetup/configs/$opts{setup}");

    
    my @expanded_list_of_dumps
        = expand_list_of_dumps(@{$setup_info->{dumps}});


    die "Expanded list of dumps is empty\n" unless @expanded_list_of_dumps;


    $setup_info->{expanded_dumps} = \@expanded_list_of_dumps;
    

    # restore dumps:
    
    foreach my $dumpfile ( @expanded_list_of_dumps ) {
        if (-r $dumpfile) {
            say STDERR "$dumpfile is readable";
        }
        else {
            die "Unreadable dumpfile: $dumpfile\n";
        }

        # If dumpfile is something like "/foo/bar/acme.20190303.bz2",
        # dbname will be "acme":
        my ($dbname) = $dumpfile =~ m|.*/([^.]+)|;

        defined $dbname || die
            "Cannot detect database name out of filename: $dumpfile\n";
    
        push @{$setup_info->{databases}}, $dbname;
    

        my $db_exists = system("psql -h db -U postgres -d $dbname -c '' >/dev/null 2>&1") == 0;

        say STDERR "Database $dbname " .
            ($db_exists?  "exists" : "does not yet exist");


        if ($db_exists && $setup_info->{force_recreate}) {
            say STDERR "Drop database due to force_recreate: $dbname";
            system "dropdb -h db -e -U postgres $dbname";

            $db_exists = 0;
        }
    
        if (!$db_exists) {
            say STDERR "Setup database: $dbname";
            # CREATE DATABASE is included in dump.
            #system "createdb -h db -e -U postgres $dbname";

            my $zipcat = $ENV{LEDGER_DOCUMENT_ROOT} . "/bin/zipcat.pl";
            system "$zipcat $dumpfile | psql -o /dev/null -h db -U postgres -q";
        }
    }


    # Create users

    foreach my $user (@{$setup_info->{users}}) {

        my $name = $user->{name} || die "No name given\n";
        
        my $lang = $user->{lang} // 'gb';
        unless (grep { $_ eq $lang } qw(de gb)) {
            die "Unsupported language for user $name: $lang\n";
        }
        
        my $pass = $user->{pass} || die "No pass for user $name given\n";
        
        say STDERR "Create user $name...";
        
        my $settings = {
            gb => {
                dateformat   => 'yyyy-mm-dd',
                numberformat => '1,000.00',
                countrycode  => '',
                dboptions    => '',
            },
            de => {
                dateformat   => 'dd.mm.yy',
                numberformat => '1.000,00',
                countrycode  => 'de',
                dboptions    => "set DateStyle to 'GERMAN'",
            }
        };
        
        chdir($ENV{LEDGER_DOCUMENT_ROOT}) || die $!;
        
        open(my $members, ">>", 'users/members') || die $!;
        
        print $members get_members_entry(
            name     => $name,
            settings => $settings->{$lang},
            pass     => $pass,
            databases => $setup_info->{databases},
        );
        
        close $members;
        
        if (my @confs = glob("users/${name}*.conf")) {
            say "Removing old users/*.conf file(s): @confs";
            unlink(@confs) || die $!;
        }
    }

}




#######################
sub get_members_entry {
#######################
    my %args = @_;

    my $pw_hash = crypt($args{pass}, substr($args{name}, 0, 2));

    my @databases = @{$args{databases}};

    my $multidb_user = 0;
    $multidb_user = 1 if @databases > 1;

    
    my $result = "";
    
    foreach my $db (@databases) {

        my $username = $multidb_user? "$args{name}\@$db" : $args{name}; 
        
        $result .= qq|
[$username]
acs=
company=$db
countrycode=$args{settings}{countrycode}
dateformat=$args{settings}{dateformat}
dbconnect=dbi:Pg:dbname=$db;host=db
dbdriver=Pg
dbhost=db
dbname=$db
dboptions=$args{settings}{dboptions}
dbpasswd=
dbport=
dbuser=sql-ledger
department=
department_id=
email=$args{name}\@localhost
fax=
menuwidth=155
name=$args{name}
numberformat=$args{settings}{numberformat}
outputformat=html
password=$pw_hash
printer=
role=user
sid=
signature=
stylesheet=sql-ledger.css
tel=
templates=templates/$args{name}
timeout=10800
vclimit=1000
warehouse=
warehouse_id=
|;

    }

    return $result;
}



##########################
sub expand_list_of_dumps {
##########################
    my @list = @_;

    my @result = ();

    say STDERR "expand_list_of_dumps: @list";

    my $dump_path = "/ledgersetup/dumps";
    say STDERR "Prepending $dump_path to each entry...";

    map { $_ = "$dump_path/$_" } @list;
    
    foreach my $entry (@list) {
        say STDERR "Parsing entry: $entry";
        $entry =~ s/\{\{(.*)?\}\}/_evaluate($1, $entry)/ge;

        say STDERR "Entry before globbing: >$entry<";
        my @globbed = glob($entry);

        say STDERR "After globbing: >", join(" ", @globbed), "<";
        push @result, @globbed;
    }

    say STDERR "Expanded list of dumps:";
    say STDERR "  - $_" foreach @result;

    return @result;
}



sub _evaluate {
    my ($expr, $entry) = @_;

    if ($expr =~ m/build_time\((.*)\)/) {
        return build_time($1);
    }
    if ($expr =~ m/latest_nonempty_dir\((.*)\)/) {
        return latest_nonempty_dir($entry);
    }
    if ($expr =~ m/param\((.*)\)/) {
        return param($1);
    }

    # otherwise
    die "Invalid expression: $expr\n";
}


sub build_time {
    my ($format) = @_;

    return Time::Piece->new->localtime->strftime($format); 
}


sub latest_nonempty_dir {
    my ($entry) = @_;

    my $dir = $entry;
    $dir =~ s/\{\{.*//;

    # say STDERR "Searching latest nonempty dir in $dir...";
    
    my ($newest_file, $newest_time) = (undef, 0);

    opendir(my $dh, $dir) or die "Error opening $dir: $!";
    while (my $file = readdir($dh)) {
        next if $file eq '.' || $file eq '..';
        my $path = File::Spec->catfile($dir, $file);
        next unless (-d $path);
        
        my ($mtime) = (stat($path))[9];
        next if $mtime < $newest_time;
        
        # We have a directory, but does it have some content?
        opendir(my $pathtest, $path) || die $!;
        my $has_content = grep ! /^\.\.?/, readdir $pathtest;
        closedir $pathtest;
        
        next unless $has_content;
        
        ($newest_file, $newest_time) = ($file, $mtime);
    }
    closedir $dh;

    return $newest_file;
}

sub param {
    my ($key) = @_;
    say STDERR "Parameter lookup: $key";

    my $value;

    if (exists $opts{param}) {
        foreach my $entry (@{$opts{param}}) {
            my ($k, $v) = split(/=/, $entry);

            $value = $v if $key eq $k;
        }

    }

    die "$opts{setup}: No value for key: $key\n" unless defined $value;
    
    return $value;
}




###################
sub write_runinfo {
###################
    my %args = @_; 
    
    my %info = (
        timestamp => Time::Piece->new->strftime,
        dumps     => $setup_info->{expanded_dumps} // {},
    );

    if (defined $args{error}) {
        $info{error} = $args{error};
        $info{status} = "Incomplete";
    }
    else {
        $info{status}  = "Complete";
        my $num = @{$setup_info->{databases} // []};

        if ($num > 0) {
            $info{status} .= " ($num database" . ($num > 1? "s" : "") . ")";
        }
    }
    
    my $infofile = "/tmp/ledgersetup/runinfo.txt";
    make_path(dirname($infofile));

    say STDERR "Writing run information to $infofile";

    open(my $runinfo, ">", $infofile) || die $!;
    $Data::Dumper::Terse=1;
    $Data::Dumper::Sortkeys=1;
    print $runinfo Dumper(\%info);
    close $runinfo;
}
