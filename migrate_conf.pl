#!/usr/bin/perl
#
# migrate_conf.pl - Migrate user .conf files into an existing members.db
#
# This script reads all .conf files from users/ directory, extracts
# sessionkey/sessioncookie and all other config fields, updates the
# corresponding rows in members.db, and moves the .conf files to
# users/user_conf_bak/.
#
# Unlike migrate_user.pl (which migrates the legacy flat-file members),
# this script only handles .conf files and requires members.db to
# already exist.
#
# Usage:  perl migrate_conf.pl [--force]
#
#   --force   Process .conf files even if they were already backed up
#
# Log output goes to both STDOUT and users/conf_migration.log
#

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/SL";

use DBI;
use File::Basename;

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
my $members_file = 'users/members';
my $db_file      = "${members_file}.db";
my $userspath    = 'users';
my $conf_bak_dir = "$userspath/user_conf_bak";
my $log_file     = 'users/conf_migration.log';

# All columns that can appear in a .conf file
my @config_fields = qw(
  acs company countrycode dateformat
  dbconnect dbdriver dbhost dbname dboptions dbpasswd
  dbport dbuser email fax menuwidth name numberformat password
  outputformat printer role sessionkey sessioncookie sid signature
  stylesheet tel templates timeout vclimit
  department department_id warehouse warehouse_id
);

my %valid_field = map { $_ => 1 } @config_fields;

# ---------------------------------------------------------------------------
# Command-line options
# ---------------------------------------------------------------------------
my $force = 0;
if (grep { $_ eq '--force' } @ARGV) {
  $force = 1;
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
open my $LOG, '>>', $log_file
  or die "Cannot open log file $log_file: $!\n";

select((select($LOG), $| = 1)[0]);
$| = 1;

sub log_msg {
  my ($msg) = @_;
  my $ts = scalar localtime;
  my $line = "[$ts] $msg";
  print $LOG "$line\n";
  print "$line\n";
}

# ---------------------------------------------------------------------------
# Step 1: Verify members.db exists
# ---------------------------------------------------------------------------
log_msg("=== Conf file migration started ===");

if (! -f $db_file) {
  log_msg("ERROR: Database '$db_file' not found. Run migrate_user.pl first.");
  close $LOG;
  exit 1;
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
  RaiseError     => 1,
  PrintError     => 0,
  AutoCommit     => 1,
  sqlite_unicode => 1,
}) or die "Cannot open database $db_file: $DBI::errstr\n";

$dbh->do("PRAGMA journal_mode=DELETE");
$dbh->do("PRAGMA busy_timeout=5000");

# Ensure sessioncookie column exists
my %existing_cols;
my $sth_info = $dbh->prepare("PRAGMA table_info(members)");
$sth_info->execute;
while (my $row = $sth_info->fetchrow_hashref) {
  $existing_cols{ lc $row->{name} } = 1;
}
$sth_info->finish;

for my $col (@config_fields) {
  unless ($existing_cols{ lc $col }) {
    $dbh->do(qq|ALTER TABLE members ADD COLUMN $col TEXT DEFAULT ''|);
    log_msg("Added missing column '$col' to members table.");
  }
}

# ---------------------------------------------------------------------------
# Step 2: Create backup directory
# ---------------------------------------------------------------------------
if (! -d $conf_bak_dir) {
  mkdir $conf_bak_dir or die "Cannot create directory '$conf_bak_dir': $!\n";
  log_msg("Created backup directory: $conf_bak_dir");
}

# ---------------------------------------------------------------------------
# Step 3: Find all .conf files
# ---------------------------------------------------------------------------
opendir(my $dh, $userspath) or die "Cannot open directory '$userspath': $!\n";
my @conf_files = grep { /\.conf$/ && -f "$userspath/$_" } readdir($dh);
closedir($dh);

log_msg("Found " . scalar(@conf_files) . " .conf file(s) in '$userspath/'.");

if (!@conf_files) {
  log_msg("No .conf files to process. Done.");
  $dbh->disconnect;
  close $LOG;
  exit 0;
}

# ---------------------------------------------------------------------------
# Step 4: Parse each .conf file and update DB
# ---------------------------------------------------------------------------
my $updated  = 0;
my $inserted = 0;
my $skipped  = 0;
my $backed_up = 0;
my $errors   = 0;

$dbh->do("BEGIN");

for my $conf_basename (sort @conf_files) {
  my $conf_file = "$userspath/$conf_basename";

  # Derive login from filename
  my $login;
  if ($conf_basename eq 'root login.conf') {
    $login = 'root login';
  } else {
    ($login = $conf_basename) =~ s/\.conf$//;
  }

  # Parse the .conf file
  my %conf_data;
  my $parse_ok = 1;
  eval {
    open(my $cfh, '<', $conf_file) or die "Cannot open $conf_file: $!";
    while (my $cline = <$cfh>) {
      # Match lines like:  key => 'value',
      if ($cline =~ /^\s*(\w+)\s*=>\s*'(.*?)'\s*,?\s*$/) {
        $conf_data{$1} = $2;
      }
    }
    close($cfh);
  };

  if ($@) {
    log_msg("WARNING: Could not parse '$conf_file': $@");
    $errors++;
    $parse_ok = 0;
  }

  if (!$parse_ok) {
    $skipped++;
    next;
  }

  # Filter to only valid config fields
  my %filtered;
  for my $key (keys %conf_data) {
    if ($valid_field{$key}) {
      $filtered{$key} = $conf_data{$key};
    }
  }

  my $field_count = scalar keys %filtered;

  if ($field_count == 0) {
    log_msg("Skipping '$conf_file' - no valid config fields found.");
    $skipped++;
    next;
  }

  # Check if user exists in DB
  my ($exists) = $dbh->selectrow_array(
    qq|SELECT COUNT(*) FROM members WHERE login = ?|, undef, $login
  );

  if ($exists) {
    # Update existing row with fields from .conf
    my @set_parts;
    my @vals;
    for my $f (@config_fields) {
      if (exists $filtered{$f} && $filtered{$f} ne '') {
        push @set_parts, "$f = ?";
        push @vals, $filtered{$f};
      }
    }

    if (@set_parts) {
      push @vals, $login;
      my $set_str = join(', ', @set_parts);
      $dbh->do(
        qq|UPDATE members SET $set_str WHERE login = ?|,
        undef, @vals
      );
      $updated++;
      log_msg("Updated user '$login' from '$conf_basename' ($field_count fields)");
    }
  } else {
    # Insert new row
    my @cols = ('login');
    my @vals = ($login);
    my @phs  = ('?');

    for my $f (@config_fields) {
      push @cols, $f;
      push @vals, ($filtered{$f} // '');
      push @phs, '?';
    }

    my $cols_str = join(', ', @cols);
    my $phs_str  = join(', ', @phs);

    $dbh->do(
      qq|INSERT INTO members ($cols_str) VALUES ($phs_str)|,
      undef, @vals
    );
    $inserted++;
    log_msg("Inserted new user '$login' from '$conf_basename' ($field_count fields)");
  }

  # Move .conf file to backup directory
  my $bak_path = "$conf_bak_dir/$conf_basename";
  if (-f $bak_path && !$force) {
    log_msg("Backup already exists: '$bak_path'. Skipping move (use --force to overwrite).");
  } else {
    if (rename $conf_file, $bak_path) {
      $backed_up++;
      log_msg("Moved '$conf_file' -> '$bak_path'");
    } else {
      log_msg("WARNING: Could not move '$conf_file' to '$bak_path': $!");
    }
  }
}

$dbh->do("COMMIT");

# ---------------------------------------------------------------------------
# Step 5: Verify
# ---------------------------------------------------------------------------
my ($total_users) = $dbh->selectrow_array(
  qq|SELECT COUNT(*) FROM members|
);

$dbh->disconnect;

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
log_msg("--- Summary ---");
log_msg("Total .conf files found : " . scalar(@conf_files));
log_msg("Users updated in DB     : $updated");
log_msg("Users inserted into DB  : $inserted");
log_msg("Files skipped           : $skipped");
log_msg("Parse errors            : $errors");
log_msg("Files backed up         : $backed_up");
log_msg("Total users in DB now   : $total_users");
log_msg("=== Conf file migration finished ===");

close $LOG;

exit 0;

