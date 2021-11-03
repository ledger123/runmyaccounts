package SL::Controller::Mojolicious;
use Mojo::Base 'Mojolicious::Controller';
use SL::Model::Config;
use File::Spec;
use File::Path qw(remove_tree);


sub hello {
    my $self = shift;

    $self->render(sometext => 'This is a minimal Mojolicious-rendered page.');
}


# We could leave that out, since it does nothing more
# than the Mojolicious default:
sub sysinfo {
    my $self = shift;

    $self->render();
}



sub expire {
    my $self = shift;

    $self->session(expires => 1);
    
    $self->render(text => "Session expired.");
}


sub clear_spool {
    my $self = shift;

    my $conf = SL::Model::Config->instance($self);

    my $path = File::Spec->catfile(
        $conf->val('x_project_root'),
        $conf->val('spool'),
    );

    remove_tree($path, {keep_root => 1} );

    $self->render(text => "Spool folder cleared: $path");
}


1;
