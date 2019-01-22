#!/usr/bin/perl
use warnings;
use strict;
use feature ':5.10';
use JSON::PP;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Cwd;
use Module::Load;
use Module::CoreList;
use CPAN::Version;
use File::Find;


# At the moment, we only take care of Debian.
# The dist.json only contains hints for Debian packages.

# Tipp for finding non-standard modules of SL:

# grep -rh "^use " | grep -v SL | awk '{print $2}' | grep '^[A-Z]' | sed 's/;//' | sort -u | xargs corelist | grep 'not in CORE'


my @fully_supported_linuxes = qw(debian);


my %pkg_manager_map = (
    debian   => "aptitude",
);

my %cpanm_packages = (
    debian   => "cpanminus make",
);

my $cpan_install_cmd = "cpanm";



# We use plain Perl, no requirements:
say "Content-type: text/html";


our $enable_setup_check = 1;

eval { require "sql-ledger.conf" };

if (!$enable_setup_check) {
    say "Status: 403 Forbidden\n";
    say "\n<h1>Forbidden</h1>";
    exit;
}

print "\n";


say qq|<!DOCTYPE html>
<html>
<head>
  <title>System requirements</title>
  <style>
body {
    font-family: Arial;
}
h1 {
    background: #ADD8E6;
    text-align: center;
}
p, td, li {
    font-size: large;
}
table {
    border-spacing: 0ex 2ex;
}
td {
    font-weight: bold;
    padding: 1ex;
}

.result {
    width:70%; 
    margin-left:15%; 
    margin-right:15%;
}

.ok {
    background: #50CC50;
    color: white;
}
.fail {
    background: #F08080;
    color: white;
}
.install_hint {
    color: black;
    background: #ADD8E6;
    border: 1px solid black;
    padding: 1ex 1ex;
    font-family: "monospace";
    font-weight: bold;
}
.tt {
    font-family: "monospace";
}
  </style>
</head>
<body>
<h1>System requirements</h1>
<p>This page will help you to identify missing system requirements (such
as Perl modules / distribution packages / executables).
</p>
|;


my ($os_pretty_name, $os_id, $os_version_id) = get_os_release();
# PRETTY_NAME="Debian GNU/Linux 9 (stretch)"
# ID=debian
# VERSION_ID="9"


say "<p>Your operating system: <b>$os_pretty_name</b>.</p>";

if ($os_id eq "unknown") {

    say "<p>Sorry, we cannot handle unknown Linuxes :-(</p>";
    exit 1;
}


if (grep { $_ eq $os_id } @fully_supported_linuxes) {

say qq|
<p>
In case of missing requirements we make suggestions based on:
<ul>
<li>
<b>$pkg_manager_map{$os_id}</b> for installation of distribution packages
</li>
<li>
  <b>$cpan_install_cmd</b> for installation of Perl modules via CPAN &nbsp;
(
<span class="tt">
$pkg_manager_map{$os_id} install $cpanm_packages{$os_id}
</span>
)
</li>
</ul>
</p>
|;
}


say qq|

<p>
When all requirements are met, you should add &nbsp;
"<span class="tt" style="background-color: yellow">\$enable_setup_check = 0;</span>"  &nbsp;
to &nbsp;<span class="tt">sql-ledger.conf</span>!
</p>
<hr/><br/>
|;



my $dist = parse_config();






my @missing_cpan_modules;
my @missing_dist_packages;


say "<table  class='result'>";

foreach my $r (sort { $a->{name} cmp $b->{name} }  @$dist) {

    my $result = check_requirement($r);
    
    say "<tr>";

    say "<td>$result->{desc}</td>";

    my $css_class = $result->{ok} ? 'ok' : 'fail';

    say "<td class='$css_class'>$result->{info}</td>";
    
    say "</tr>";
}

say "</table><br/>";


if (my @somehow_used_modules = get_somehow_used_modules()) {
    say "<hr/>";

    say "<p>FYI: Other somehow used modules:";

    say "<pre>";
    
    say foreach  @somehow_used_modules;

    say "</pre></p>";
}



if (@missing_dist_packages || @missing_cpan_modules) {
    say "<hr/>";
}



if (@missing_dist_packages) {

    say qq|
<p>Install missing distribution packages with:</p>
<div class='install_hint'>
$pkg_manager_map{$os_id} install @missing_dist_packages
</div>
|;
}

if (@missing_cpan_modules) {

    say qq|
<p>If your distro does not provide suitable packages, install missing CPAN modules with:</p>
<div class='install_hint'>
$cpan_install_cmd @missing_cpan_modules
</div>
|;
}



say qq|
</body>
</html>
|;


exit 0;



################################# End main #################################



####################
sub get_os_release {
####################
    open(my $osrelease, "<", "/etc/os-release") ||
        return ("unknown", "unknown", "unknown");

    my %keys;
    
    while (<$osrelease>) {
        m/^(\w+)=["']?(.+?)["']?$/;
        $keys{$1} = $2;
    }

    return ($keys{PRETTY_NAME}, $keys{ID}, $keys{VERSION_ID});
}



##################
sub parse_config {
##################
    local $/;
    open( my $conf, '<', 'dist.json' );
    my $json_text   = <$conf>;
    close $conf;
    return decode_json( $json_text );
}



#######################
sub check_requirement {
#######################
    my $r = shift;

    my %type_map = (
        perlmodule => "Perl module",
        executable => "Executable",
    );

    
    if ($r->{type} eq "perlmodule") {

        my $loadable   = 0;
        my $version_ok = 0;
        my $info;
        
        eval { load $r->{name} };

        $loadable = 1 unless $@;
        
        if ($loadable) {
            my $version = "$r->{name}"->VERSION();

            if (CPAN::Version->vcmp($version, $r->{version}) >= 0) {
                # 1: first is larger, 0: equal
                
                $version_ok = 1;
                $info = "Installed version: $version";
            }
            else {
                $info = "Installed in version $version, " .
                    "but we need $r->{version}";
            }
        }
        else {
            $info = "Not installed";
            $info .= " (required version: $r->{version})" if $r->{version};
        }

        if (!$loadable || !$version_ok) {
            if (my $p = get_package($r)) {
                push @missing_dist_packages, $p;
            }
            else {
                push @missing_cpan_modules,
                    $r->{name} . ($r->{version} ne "0"? "\@$r->{version}" : "");
            }
        }

        return {
            desc => $type_map{ $r->{type} } . ": " . $r->{name},
            ok   =>  $loadable && $version_ok,
            info => $info,
        }
    }
    
    elsif ($r->{type} eq "executable") {

        my $is_in_path = 0;
        my $info;

        my @found;
        if (@found = grep { -x "$_/$r->{name}" } split /:/, $ENV{PATH}) {
            $is_in_path = 1;
        }

        if ($is_in_path) {
            $info = "$r->{name} is in $found[0]";
        }
        else {
            $info = "Not found";
            if (my $p = get_package($r)) {
                push @missing_dist_packages, $p;
            }
            else {
                die "No package configured";
            }
        }
        
        return {
            desc => $type_map{ $r->{type} } . ": " . $r->{name},
            ok   =>  $is_in_path,
            info => $info,
        }
    }
    else {
        die "Unknown type";
    }
}



#################
sub get_package {
#################
    my $r = shift;

    if ( $r->{package} ) {
        return $r->{package}{"$os_id$os_version_id"}
            // $r->{package}{$os_id};
    }
}



##############################
sub get_somehow_used_modules {
##############################

    my %overall_used_modules;
    my @whitelist = (
        qr/^\$0$/,
        qr/^(strict|warnings|utf8|v5\.10)$/,
        qr/^SL::.*/,
        qr/^GD::Graph::.*/,
        qr/^Mojo::(File|Home|Base)$/,
        qr/^Mojolicious::(Commands|Static)$/,
    );


    my @known_required_modules =
        map { $_->{name} } grep { $_->{type} eq 'perlmodule' } @$dist;


    my $wanted = sub {
        return unless -f;

        open(my $file, "<", $_) || warn $!;
        
        while (<$file>) {
            chomp;
            if (my ($used) = m/^use\s+(\S+)(\s+|;)/) {
                if ((!grep { $used =~ $_ } @whitelist)
                     && (!grep { $used eq $_ } @known_required_modules)
                     && (!Module::CoreList::is_core($used))
                    ) {
                    $overall_used_modules{$1} = 1;
                }
            }
        }
        close $file;
    };
    
    find($wanted, getcwd);
    
    return sort keys %overall_used_modules;
}
