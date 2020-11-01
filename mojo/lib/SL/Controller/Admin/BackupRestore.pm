package SL::Controller::Admin::BackupRestore;
use Mojo::Base 'Mojolicious::Controller';

use SL::Model::Config;
use strict;
use warnings;
use utf8;
use POSIX qw/strftime/;
use File::Spec;
use IO::Uncompress::AnyUncompress qw(anyuncompress $AnyUncompressError);


use Mojo::Pg;


sub start {
    my $c = shift;

    my $connstr = $c->admin_pg_connstr(
        dbhost    => $c->param('dbhost'),
        dbdefault => $c->param('dbdefault'),
        dbuser    => $c->param('dbuser'),
        dbpasswd  => $c->param('dbpasswd'),
        dbport    => $c->param('dbport'),
    );
    
    my $sql = qq{
SELECT
  datname,
  (SELECT round(pg_database_size(datname) / 1024.0 / 1024.0, 1)) || ' MB'
FROM pg_database
WHERE datname NOT IN ('postgres', 'template0', 'template1')
ORDER BY datname
};

    my $pg = Mojo::Pg->new($connstr);

    eval { $pg->db->ping };
    return if $c->exception_happened();
    
    my $dbinfos = eval {
        $pg->db->query($sql)->arrays->to_array
    };
    
    $c->render(
        dbinfos => $dbinfos
    );
}


sub backup {
    my $c = shift;

    my $dbname = $c->param('dbname');
    my $date = strftime("%Y%m%d", localtime);
    
    $c->res->headers->content_type("application/octet-stream");
    $c->res->headers->content_disposition(
        "attachment; filename=${dbname}.${date}.sql.bz2"
    );

    my $connstr = $c->admin_pg_connstr(dbname => $dbname);

    my $pg_dump_cmd = join(' ',
                           'pg_dump',
                           '--dbname', $connstr,
                           '-C',         # with create statements!
                           '| bzip2 -c'
                       );
    ###say STDERR $pg_dump_cmd;
    
    open(my $cmd_handle, "-|", $pg_dump_cmd) || die $!;

    my $content;
    while (read($cmd_handle, $content, 1024) ) {
        
        $c->write($content);
    }
    close $cmd_handle;
    $c->finish();
}



sub restore {
    my $c = shift;

    my $conf = SL::Model::Config->instance($c);

    my $upload          = $c->param('upload');
    my $upload_filename = $upload->filename;


    if ($upload_filename =~ m/^\s*$/ ) {
        $c->exception('No file chosen') && return;
    }
    
    my $uncompressed;
    anyuncompress \($upload->slurp()) => \$uncompressed;

    my ($restore_dataset_name) = $uncompressed =~ m/^CREATE DATABASE (\S+)/sm;

    if (!$restore_dataset_name) {
        $c->exception('No CREATE DATABASE statement found',
                      "We can only handle PostgreSQL dumps created with 'pg_dump -C'.")
            && return;
    }

    
    my $pg = Mojo::Pg->new($c->admin_pg_connstr(
        dbname => $c->session('dbdefault')
    ));

    my $sql = qq{ SELECT datname FROM pg_database WHERE datname = ? };
    my $result = eval {
        $pg->db->query($sql, $restore_dataset_name)->arrays->to_array
    };
    my $already_exists = @$result;

    
    if ( $already_exists && $c->param('procedure') eq 'die' ) {
        $c->exception("Dataset already exists",
                      "The dataset '$restore_dataset_name' already exists")
            && return;
    }

    if ( $already_exists && $c->param('procedure') eq 'rename' ) {
        my $rename_in = $c->param('rename_in');
        if ($rename_in =~ /^\s*$/ ) {
            $c->exception("Cannot rename: No name given")
                && return;
        }
        
        $sql = "ALTER DATABASE " . $restore_dataset_name .
            " RENAME TO " . $rename_in;
        eval { $pg->db->query($sql) };
        return if $c->exception_happened();
    }

    if ( $already_exists && $c->param('procedure') eq 'drop' ) {
        $sql = "DROP DATABASE " . $restore_dataset_name;
        eval { $pg->db->query($sql) };
        return if $c->exception_happened();
    }


    # Now we should be able to restore:
    my $pg_restore_cmd = join(' ',
                              'psql',
                              '--dbname', $c->admin_pg_connstr,
                              '>/dev/null'
                          );
    
    eval {
        open(my $cmd_handle, "|-", $pg_restore_cmd) || die $!;
        print $cmd_handle $uncompressed;
        close $cmd_handle;
    };
    return if $c->exception_happened();
    
    $c->render("admin/backup_restore/restored",
               dataset_name => $restore_dataset_name);
}



1;
