package SL::Controller::Database;
use Mojo::Base 'Mojolicious::Controller';

use SL::Model::Config;
use strict;
use warnings;
use utf8;
use POSIX qw/strftime/;


sub backup_restore {
    my $c = shift;

    my $sql = qq{
SELECT
  datname,
  (SELECT round(pg_database_size(datname) / 1024.0 / 1024.0, 1)) || ' MB'
FROM pg_database
WHERE datname NOT IN ('postgres', 'template0', 'template1')
ORDER BY datname
};

    my $pg = $c->mojo_pg->{object};

    my $dbinfos = eval {
        $pg->db->query($sql)->arrays->to_array
    };
    $c->exception("Database problem", qr/connect/) && return;
    
    $c->render(
        dbinfos => $dbinfos
    );
}


sub backup {
    my $c = shift;

    use Data::Dumper;

    #print STDERR Dumper $c->pg;

    my $dbname = $c->mojo_pg->{access_data}{dbname} || 'database';
    my $iso_date = strftime("%Y-%m-%d", localtime);
    
    $c->res->headers->content_type("application/octet-stream");
    $c->res->headers->content_disposition(
        "attachment; filename=${dbname}_${iso_date}.sql.gz"
    );

    my $pg_dump_cmd = join(' ',
                           'pg_dump',
                           '--dbname', $c->mojo_pg->{connstr},
                           '| gzip -c'
                       );
    say STDERR $pg_dump_cmd;
    
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

    my $upload          = $c->param('upload');
    my $upload_filename = $upload->filename;

    my $dataset_name;

    if ($upload_filename eq '' ) {
        $c->exception(
            "No filename specified",
        ) && return;
    }
    
    if ($upload_filename =~ m/^(\w+?)([_-]\d{4}-\d{2}-\d{2})?\.sql\.gz$/ ) {
        $dataset_name = $1;
    }
    else {
        my $samples = '<br>test.sql.gz<br>test-2018-11-24.sql.de<br>test_2018-11-24.sql.de';
        $c->exception(
            "Invalid filename",
            "Examples of allowed filenames",
            ":<br><pre>$samples</pre>"
        ) && return;
    }

    if ($c->param('naming_strategy') eq 'static') {
        $dataset_name = $c->param('dataset_name');
    }

    if ($dataset_name !~ m/^\w+$/ ) {
        $c->exception(
            "Invalid dataset name",
        ) && return;
    }

    
    my $text;


    $text .= "Restoring $upload_filename into '$dataset_name'\n";


    my $pg = $c->mojo_pg->{object};

    # Create new database:
    eval { $pg->db->query("CREATE DATABASE $dataset_name") };
    $c->exception("Database problem", qr/./) && return;
    

    $c->param(dbname => $dataset_name);
    
    my $pg_restore_cmd = join(' ',
                              'gzip -d |',
                              'psql',
                              '--dbname', $c->mojo_pg->{connstr},
                              '>/dev/null'
                          );
    say STDERR $pg_restore_cmd;

    eval {
        open(my $cmd_handle, "|-", $pg_restore_cmd) || die $!;
        print $cmd_handle $upload->slurp;
        close $cmd_handle;
    };
    $c->exception("Problem", qr/./) && return;
    
    $c->render(dataset_name => $dataset_name);
}



1;
