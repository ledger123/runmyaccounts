#!/usr/bin/perl
#
# migrate_user.pl - Migrate users from legacy flat-file (users/members)
#                   to SQLite database (users/members.db)
#
# Usage:  perl migrate_user.pl
#
# Log output goes to both STDOUT and users/members_migration.log
#

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use lib "$FindBin::Bin/SL";

use DBI;

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
my $members_file = 'users/members';
my $db_file      = "${members_file}.db";
my $log_file     = 'users/members_migration.log';

# All columns that must exist in the members table.
# Based on User::config_vars and fields actually present in the legacy file.
my @config_fields = qw(
  acs company countrycode dateformat
  dbconnect dbdriver dbhost dbname dboptions dbpasswd
  dbport dbuser email fax menuwidth name numberformat password
  outputformat printer role sessionkey sid signature
  stylesheet tel templates timeout vclimit
  department department_id warehouse warehouse_id
);

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
open my $LOG, '>>', $log_file
  or die "Cannot open log file $log_file: $!\n";

# autoflush both handles
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
# Step 1: Create / verify SQLite database and schema
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Command-line options
# ---------------------------------------------------------------------------
my $force = 0;
if (grep { $_ eq '--force' } @ARGV) {
  $force = 1;
}

log_msg("=== Migration started ===");
log_msg("Members file : $members_file");
log_msg("Database file: $db_file");

# If --force, delete old DB and journal files for a clean start
if ($force && -f $db_file) {
  log_msg("--force flag set. Removing existing database and journal files.");
  unlink $db_file;
  unlink "${db_file}-wal"  if -f "${db_file}-wal";
  unlink "${db_file}-shm"  if -f "${db_file}-shm";
  unlink "${db_file}-journal" if -f "${db_file}-journal";

  # Also restore members from .bak if needed
  if (!-f $members_file && -f "${members_file}.bak") {
    rename "${members_file}.bak", $members_file;
    log_msg("Restored '$members_file' from '${members_file}.bak' for re-migration.");
  }
}

# Clean up stale WAL/SHM files if DB does not exist (leftover from previous runs)
if (! -f $db_file) {
  unlink "${db_file}-wal"  if -f "${db_file}-wal";
  unlink "${db_file}-shm"  if -f "${db_file}-shm";
  unlink "${db_file}-journal" if -f "${db_file}-journal";
}

my $db_existed = -f $db_file;

my $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", "", "", {
  RaiseError     => 1,
  PrintError     => 0,
  AutoCommit     => 1,
  sqlite_unicode => 1,
}) or die "Cannot open database $db_file: $DBI::errstr\n";

# Use DELETE journal mode to avoid WAL file permission issues in CGI
$dbh->do("PRAGMA journal_mode=DELETE");
$dbh->do("PRAGMA foreign_keys=ON");

# Build column definitions
my $col_defs = join(",\n    ", map { "$_ TEXT DEFAULT ''" } @config_fields);

$dbh->do(qq|
  CREATE TABLE IF NOT EXISTS members (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    login TEXT    NOT NULL UNIQUE,
    $col_defs
  )
|);

if ($db_existed) {
  log_msg("Database already existed. Ensured table schema is up to date.");
  # Add any missing columns (safe for re-runs)
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
  # Ensure 'id' column exists (upgrade from old schema without id)
  unless ($existing_cols{'id'}) {
    log_msg("WARNING: Existing table lacks 'id' column. SQLite cannot add AUTOINCREMENT to existing table.");
    log_msg("Consider deleting $db_file and re-running migration for a clean schema.");
  }
} else {
  log_msg("Created new database with members table (id INTEGER PRIMARY KEY AUTOINCREMENT, login UNIQUE, + config fields).");
}

# ---------------------------------------------------------------------------
# Step 2: Check if migration is needed
# ---------------------------------------------------------------------------
if (! -f $members_file) {
  if (-f "${members_file}.bak") {
    log_msg("Legacy members file not found, but ${members_file}.bak exists. Migration was already performed. Nothing to do.");
  } else {
    log_msg("ERROR: Legacy members file '$members_file' not found. Nothing to migrate.");
  }
  $dbh->disconnect;
  close $LOG;
  exit 0;
}

# ---------------------------------------------------------------------------
# Step 3: Parse legacy members file
# ---------------------------------------------------------------------------
log_msg("Parsing legacy members file: $members_file");

open(my $fh, '<', $members_file)
  or die "Cannot open $members_file: $!\n";

my @entries;        # list of { login => '...', fields => { ... } }
my $cur_login = '';
my %cur_data;

while (my $line = <$fh>) {
  chomp $line;

  # New section header: [login_name]
  if ($line =~ /^\[(.+)\]/) {
    if ($cur_login ne '') {
      push @entries, { login => $cur_login, fields => { %cur_data } };
    }
    $cur_login = $1;
    %cur_data  = ();
    next;
  }

  # Skip comments and blank lines
  next if $line =~ /^\s*#/;
  next if $line =~ /^\s*$/;

  # Trim whitespace
  $line =~ s/^\s+//;
  $line =~ s/\s+$//;

  # key=value
  if ($line =~ /^([^=]+)=(.*)$/) {
    $cur_data{$1} = $2;
  }
}

# Don't forget the last section
if ($cur_login ne '') {
  push @entries, { login => $cur_login, fields => { %cur_data } };
}

close($fh);

log_msg("Parsed " . scalar(@entries) . " user section(s) from members file.");

# ---------------------------------------------------------------------------
# Step 4: Insert / update users in SQLite
# ---------------------------------------------------------------------------
my $migrated     = 0;
my $skipped      = 0;
my $root_found   = 0;

$dbh->do("BEGIN");

for my $entry (@entries) {
  my $login  = $entry->{login};
  my $fields = $entry->{fields};

  # Track root login
  if ($login eq 'root login') {
    $root_found = 1;
  }

  # Build column lists
  my @cols = ('login');
  my @vals = ($login);
  my @phs  = ('?');

  for my $f (@config_fields) {
    push @cols, $f;
    push @vals, ($fields->{$f} // '');
    push @phs,  '?';
  }

  my $cols_str = join(', ', @cols);
  my $phs_str  = join(', ', @phs);

  # Build ON CONFLICT UPDATE clause for upsert
  my @update_parts = map { "$_ = excluded.$_" } @config_fields;
  my $update_str   = join(', ', @update_parts);

  my $sql = qq|INSERT INTO members ($cols_str)
               VALUES ($phs_str)
               ON CONFLICT(login) DO UPDATE SET $update_str|;

  $dbh->do($sql, undef, @vals);
  $migrated++;

  # Count non-empty fields for log context
  my $field_count = grep { defined $fields->{$_} && $fields->{$_} ne '' } @config_fields;
  log_msg("Migrated user: '$login' ($field_count non-empty fields)");
}

$dbh->do("COMMIT");

# ---------------------------------------------------------------------------
# Step 5: Ensure root login exists
# ---------------------------------------------------------------------------
if (!$root_found) {
  log_msg("Root login was not found in the members file. Inserting default 'root login' entry.");
  $dbh->do(qq|INSERT OR IGNORE INTO members (login, password) VALUES ('root login', '')|);
} else {
  log_msg("Root login was successfully migrated from the members file.");
}

# ---------------------------------------------------------------------------
# Step 6: Verify migration
# ---------------------------------------------------------------------------
my ($total_users) = $dbh->selectrow_array(
  qq|SELECT COUNT(*) FROM members|
);
my ($root_exists) = $dbh->selectrow_array(
  qq|SELECT COUNT(*) FROM members WHERE login = 'root login'|
);

log_msg("--- Verification ---");
log_msg("Total rows in members table: $total_users");
log_msg("Root login present: " . ($root_exists ? "YES" : "NO"));

# List all columns in the table for verification
my $sth_cols = $dbh->prepare("PRAGMA table_info(members)");
$sth_cols->execute;
my @col_names;
while (my $row = $sth_cols->fetchrow_hashref) {
  push @col_names, $row->{name};
}
$sth_cols->finish;
log_msg("Table columns (" . scalar(@col_names) . "): " . join(', ', @col_names));

$dbh->disconnect;

# ---------------------------------------------------------------------------
# Step 7: Backup the legacy file
# ---------------------------------------------------------------------------
my $bak_file = "${members_file}.bak";
if (-f $members_file) {
  if (rename $members_file, $bak_file) {
    log_msg("Renamed legacy file '$members_file' -> '$bak_file'");
  } else {
    log_msg("WARNING: Could not rename '$members_file' to '$bak_file': $!");
  }
}

# ---------------------------------------------------------------------------
# Done — fix file permissions for web server access
# ---------------------------------------------------------------------------
# Set permissions to rw-rw-rw- (666) so Apache/CGI can read and write
# regardless of which user ran this migration script
chmod 0666, $db_file;
log_msg("Set file permissions on '$db_file' to 0666 (rw-rw-rw-).");

# Try to detect web server user and chown the db file
for my $webuser ('apache', 'www-data', 'httpd', 'www') {
  my ($uid, $gid) = (getpwnam($webuser))[2,3];
  if (defined $uid) {
    if (chown($uid, $gid, $db_file)) {
      log_msg("Changed ownership of '$db_file' to $webuser.");
    } else {
      log_msg("WARNING: Could not chown '$db_file' to $webuser: $!. Run: sudo chown $webuser '$db_file'");
    }
    last;
  }
}

log_msg("Migration completed. Migrated $migrated user(s), skipped $skipped.");
log_msg("=== Migration finished ===");

close $LOG;

exit 0;

