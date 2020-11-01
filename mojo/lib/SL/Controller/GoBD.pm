package SL::Controller::GoBD;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Static;
use Mojo::File;

use SL::Model::Config;
use SL::Model::GoBD::Export;
use SL::Model::SQL::Statement;

use File::Spec;
use File::Basename;
use utf8;

sub start {
    my $c = shift;

    my $conf = SL::Model::Config->instance($c);
    
    my $sth = SL::Model::SQL::Statement->new(
        config => $conf,
        query  => "common/earliest_trans_year"
    );
    
    my $result = $sth->execute->fetch;
    
    $c->render("gobd/start", earliest_trans_year => $result->[0][0]);
}


sub generate {
    my $c = shift;
    my $conf = SL::Model::Config->instance($c);

    $c->app->plugin('SL::Helper::DateIntervalPicker');
    
    my ($from_iso, $to_iso) = $c->foo;

    unless (defined($from_iso) && defined($to_iso)) {
        $c->render("gobd/start", value_error => 1);
        return;
    }

    my $export = SL::Model::GoBD::Export->new(
        config   => $conf,
        from     => $from_iso,
        to       => $to_iso,
    );

    $export->create();
    
    $c->session(gobd_workdir      => $export->{workdir});
    $c->session(gobd_zipfile_path => $export->{zipfile_path});
    
    $c->render("gobd/created", export => $export);
}



sub show {
    my $c = shift;

    my $workdir = $c->session('gobd_workdir');

    my $path = Mojo::File->new(
        File::Spec->catfile($workdir, $c->param('filename'))
      );

    $c->res->headers->content_type('text/plain; charset=utf-8');
    $c->render(data => $path->slurp);
}


sub download {
    my $c = shift;

    my $workdir = $c->session('gobd_workdir');
    my $zipfile_dir  =  dirname($c->session('gobd_zipfile_path'));
    my $zipfile_name = basename($c->session('gobd_zipfile_path'));

    my $static = Mojolicious::Static->new( paths => [ $zipfile_dir ] );

    $c->res->headers->content_type("application/octet-stream");
    $c->res->headers->content_disposition("attachment; filename=$zipfile_name");

    $static->serve($c, $zipfile_name);
}


1;
