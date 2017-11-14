package SL::Controller::GoBD;
use Mojo::Base 'Mojolicious::Controller';
use Mojolicious::Static;
use Mojo::File;

use SL::Model::Config;
use SL::Model::GoBD::Export;
use File::Spec;
use File::Basename;
use utf8;

sub index {
    my $c = shift;

    my $validation = $c->validation;
    return $c->render ### unless #$validation->has_data;
        unless defined $c->param('from') || defined $c->param('to');
    
    my $conf = SL::Model::Config->instance($c);

    my ($from_iso, $to_iso);
    $validation->required('from')->valid_date($conf, \$from_iso);
    $validation->required('to')  ->valid_date($conf, \$to_iso);

    return $c->render if $validation->has_error;

    
    my $export = SL::Model::GoBD::Export->new(
        config   => $conf,
        from     => $from_iso,
        to       => $to_iso,
        longname    => $c->param('longname'),
    );

    $export->create();

    $c->session(workdir => $export->{workdir});
    $c->session(zipfile_path => $export->{zipfile_path});

    $c->render("go_b_d/created", export => $export);
}


sub show {
    my $c = shift;

    my $workdir = $c->session('workdir');

    #my $static = Mojolicious::Static->new( paths => [ $workdir ] );
    #my $types = Mojolicious::Types->new;

    my $path = Mojo::File->new(
        File::Spec->catfile($workdir, $c->param('filename'))
      );

    $c->res->headers->content_type('text/plain; charset=utf-8');
    $c->render(data => $path->slurp);
}


sub download {
    my $c = shift;

    my $workdir = $c->session('workdir');
    my $zipfile_dir  =  dirname($c->session('zipfile_path'));
    my $zipfile_name = basename($c->session('zipfile_path'));

    my $static = Mojolicious::Static->new( paths => [ $zipfile_dir ] );

    $c->res->headers->content_type("application/octet-stream");
    $c->res->headers->content_disposition("attachment; filename=$zipfile_name");

    $static->serve($c, $zipfile_name);
}

1;
